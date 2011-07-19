
module Graph
  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  class GraphEdgeFromDirective
    def initialize(from, options)
      @from, @options = from, options
    end
    def from
      @from
    end
    def options
      @options
    end
  end

  class GraphNodeDirective
    def initialize(options)
      @options = options
    end
    def options
      @options
    end
  end

  module ClassMethods

    # Describes a graph edge which is created by this model.  A graph
    # edge consists of a start node (:from), a verb and an end node
    # (:to). Conceptually it represents a subject-verb-object,
    # e.g. "User X purchased Item Y." where starting node is User X,
    # verb is "purchased" and end node is Item Y.
    #
    # A node can be an ActiveRecord object or a string. A verb is
    # always a string.
    #
    # The first argument is a method name for the starting node
    # (typically this is an assciation). The end node (:to) will
    # default to the ActiveRecord object where the directive is
    # specified. :verb defaults to the name of the class of the
    # current object.
    #
    # === Options
    # [:to]
    #   Method, proc or string to call to get the end node of this
    #   edge. Defaults to the current object.
    # [:verb]
    #   Method, proc or string to call to get the name of the
    #   verb. Defaults to current object's class name. Note that
    #   internally all verbs are prepended with a '>' or '<'
    #   indicating direction, e.g. User:123:>Purchased => Item:345,
    #   Item:345:<Purchased => User:123.
    # [:on]
    #   :save (default), :create or :update. When the edge is actually
    #   created.
    # [:if, :unless]
    #    Method, proc or string to call to determine whether the edge
    #    should be stored.
    #
    # === Example
    #
    # User
    #   has_many :orders
    # Order
    #   belongs_to :user
    #   has_many :items, :through => :order_items
    # OrderItem
    #   belongs_to :order
    #   has_one :user, :through => :order
    #   has_one :item
    #   graph_edge_from :user, :to => :item, :verb => 'Purchased', :on => :create

    def graph_edge_from(from, options={})
      options.assert_valid_keys([:to, :verb, :on, :if, :unless])

      options[:to] = self.class.name.underscore.to_sym unless options[:to]
      options[:on] = :save unless options[:on]

      directive = GraphEdgeFromDirective.new(from, options)
      write_inheritable_array(:graph_edge_from_directives, [directive])

      include_graph_edge_from_instance_methods do
        case options[:on]
        when :save   then after_save :store_graph_edge
        when :create then after_create :store_graph_edge
        when :update then after_update :store_graph_edge
        end
      end
    end

    # A graph node is an object whose id is stored in a graph as a
    # result of a graph_edge_from directive. A graph node will have
    # methods to do things with the graph such as find neighbors.
    #
    # === Options
    # [:verbs]
    # An array of verbs that edges connecting this node would
    # have. This is necessary because we do not maintain a global list
    # of verbs, the verbs have to be explicitely named. NOTE that
    # verbs here must specify direction in the first character, '>' or
    # '<'.
    #
    # === Example
    # class User < ActiveRecord::Base
    #   graph_node :verbs => '>Purchased'
    #    ...
    # class Item < ActiveRecord::Base
    #   graph_node :verbs => '<Purchased'

    def graph_node(options={})
      options.assert_valid_keys([:verbs])

      directive = GraphNodeDirective.new(options)
      write_inheritable_array(:graph_node_directives, [directive])

      include_graph_node_instance_methods
    end

    private

    def include_graph_edge_from_instance_methods(&block)
      unless included_modules.include? GraphEdgeFromInstanceMethods
        yield if block_given?
        include GraphEdgeFromInstanceMethods
      end
    end

    def include_graph_node_instance_methods(&block)
      unless included_modules.include? GraphNodeInstanceMethods
        yield if block_given?
        include GraphNodeInstanceMethods
      end
    end

  end

  module GraphEdgeFromInstanceMethods

    private

    def store_graph_edge
      self.class.read_inheritable_attribute(:graph_edge_from_directives).each do |directive|

        if should_method_run?(directive.options, self)

          from = directive.from.is_a?(Proc) ? evaluate_method(directive.from, self) : instance_eval(directive.from.to_s)
          from_obj_class, from_obj_val = obj_parts(from)

          to = directive.options[:to].is_a?(Proc) ? evaluate_method(directive.options[:to], self) : instance_eval(directive.options[:to].to_s)
          to_obj_class, to_obj_val = obj_parts(to)

          verb = directive.options[:verb] || "#{self.class.name}"
          verb = evaluate_method(verb, self) if verb.is_a? Proc

          # forward
          key = "#{from_obj_class}:#{from_obj_val}:>#{verb}"
          val = "#{to_obj_class}:#{to_obj_val}"
          #puts "Forward: #{key} #{val}" 
          $redis.sadd(key, val)

          # reverse 
          key = "#{to_obj_class}:#{to_obj_val}:<#{verb}"
          val = "#{from_obj_class}:#{from_obj_val}"
          #puts "Reverse: #{key} #{val}"
          $redis.sadd(key, val)

        end
      end
    end

    def obj_parts(obj)
      # it's either an AR object or a String
      [obj.class.name, obj.is_a?(ActiveRecord::Base) ? obj.id : obj.to_s]
    end

    def evaluate_method(method, *args, &block)
      case method
      when Symbol
        object = args.shift
        object.send(method, *args, &block)
      when String
        eval(method, args.first.instance_eval { binding })
      when Proc, Method
        method.call(*args, &block)
      else
        if method.respond_to?(kind)
          method.send(kind, *args, &block)
        else
          raise ArgumentError,
          "Callbacks must be a symbol denoting the method to call, a string to be evaluated, " +
            "a block to be invoked, or an object responding to the callback method."
        end
      end
    end

    def should_method_run?(options, *args)
      [options[:if]].flatten.compact.all? { |a| evaluate_method(a, *args) } &&
        ![options[:unless]].flatten.compact.any? { |a| evaluate_method(a, *args) }
    end

  end

  module GraphNodeInstanceMethods

    # somehow this little function needs to take distance as an
    # argument, and it should default to 1

    def graph_neighbors(*args)
      verbs, distance = graph_check_args(*args)

      result = Set.new
      verbs.each do |verb|
        current_distance = Set.new(["#{self.class.name}:#{self.id}"])
        distance.times do
          result.clear
          current_distance.each { |node| result.merge($redis.smembers("#{node}:#{verb}")) }
          verb = verb[0,1] == '>' ? '<'+verb[1..-1] : '>'+verb[1..-1] # flip direction
          current_distance.replace(result)
        end
      end
      result
    end

    def graph_neighbors_ranked(*args)
      verbs, distance = graph_check_args(*args)

      result = {}
      verbs.each do |verb|
        current_distance = Set.new(["#{self.class.name}:#{self.id}"])
        distance.times do
          result.clear
          current_distance.each do |node|
            $redis.smembers("#{node}:#{verb}").each do |node2|
              result[node2] = (result[node2] || 0) + 1
            end
          end
          verb = verb[0,1] == '>' ? '<'+verb[1..-1] : '>'+verb[1..-1] # flip direction
          current_distance.replace(result.keys)
        end
      end
      result = Array(result).map {|k,v| [v,k]}
      result.sort.reverse
    end

    private

    def graph_check_args(*args)
      options = args.extract_options!
      options.assert_valid_keys([:distance])
      if args.present?
        verbs = Set.new(args.flatten)
      else
        verbs = Set.new
        self.class.read_inheritable_attribute(:graph_node_directives).each do |directive|
          verbs.merge(directive.options[:verbs])
        end
      end
      verbs.each do |verb|
        unless ['<','>'].include? verb[0,1]
          raise ArgumentError, "Verb '#{verb}' does not begin with '>' or '<'"
        end
      end
      distance = options[:distance] || 1
      return [verbs, distance]
    end

  end
end
