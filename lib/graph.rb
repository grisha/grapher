
module Graph
  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  class GraphReflection
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
    @@valid_keys_for_graph_edge_from = [:to, :verb]
    def graph_edge_from(name, options={})
      options.assert_valid_keys(valid_keys_for_graph_edge_from)

      options[:to] = self.class.name.underscore.to_sym unless options[:to]

      reflection = GraphReflection.new(name, options)
      write_inheritable_hash(:graph_reflections, name => reflection)

      include_graph_instance_methods do
        # TODO at which point it is stored should be configurable
        #after_create :store_graph_edge
        after_save :store_graph_edge
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
      self.class.read_inheritable_attribute(:graph_reflections).each do |name, reflection|

        from_obj = self.instance_eval(reflection.name.to_s)
        from_obj_class = from_obj.class.name
        from_obj_val = from_obj.is_a?(ActiveRecord::Base) ? from_obj.id : from_obj.to_s

        verb = reflection.options[:verb] || "#{self.class.name}"

        to_obj = self.instance_eval(reflection.options[:to].to_s)
        to_obj_class = to_obj.class.name
        to_obj_val = to_obj.is_a?(ActiveRecord::Base) ? to_obj.id : to_obj.to_s

        # forward
        key = "#{from_obj_class}:#{from_obj_val}:>#{verb}"
        val = "#{to_obj_class}:#{to_obj_val}"
        $redis.sadd(key, val)

        # reverse 
        key = "#{to_obj_class}:#{to_obj_val}:<#{verb}"
        val = "#{from_obj_class}:#{from_obj_val}"
        $redis.sadd(key, val)
      end
    end

  end
end
