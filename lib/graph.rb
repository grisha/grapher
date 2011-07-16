
module Graph
  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  class GraphDirective
    def initialize(name, options)
      @name, @options = name, options
    end
    def name
      @name
    end
    def options
      @options
    end
  end

  module ClassMethods

    mattr_accessor :valid_keys_for_graph_edge_from
    @@valid_keys_for_graph_edge_from = [:to, :verb, :on, :if, :unless]
    def graph_edge_from(name, options={})
      options.assert_valid_keys(valid_keys_for_graph_edge_from)

      options[:to] = self.class.name.underscore.to_sym unless options[:to]
      options[:on] = :save unless options[:on]

      directive = GraphDirective.new(name, options)
      write_inheritable_array(:graph_directives, [directive])

      include_graph_instance_methods do
        case options[:on]
        when :save   then after_save :store_graph_edge
        when :create then after_create :store_graph_edge
        when :update then after_update :store_graph_edge
        end
      end
    end

    private

    def include_graph_instance_methods(&block)
      unless included_modules.include? InstanceMethods
        yield if block_given?
        include InstanceMethods
      end
    end

  end

  module InstanceMethods

    private

    def store_graph_edge
      self.class.read_inheritable_attribute(:graph_directives).each do |directive|

        if should_method_run?(directive.options, self)

          from_obj_class, from_obj_val = obj_parts(self.instance_eval(directive.name.to_s))
          to_obj_class, to_obj_val = obj_parts(self.instance_eval(directive.options[:to].to_s))
          verb = directive.options[:verb] || "#{self.class.name}"

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
end
