
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

    def graph_neighbors(*args)
      if args.present?
        verbs = Set.new(args.flatten)
      else
        verbs = Set.new
        self.class.read_inheritable_attribute(:graph_node_directives).each do |directive|
          verbs.merge(directive.options[:verbs])
        end
      end
      result = Set.new
      verbs.each do |verb|
        result.merge($redis.smembers("#{self.class.name}:#{self.id}:#{verb}"))
      end
      result
    end

  end
end
