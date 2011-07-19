require 'test_helper'

class GrapherTest < ActiveSupport::TestCase

  load_schema
  load_data

  test "graph_neighbors" do
    assert User.find(1).graph_neighbors == Set.new(["Item:1", "Item:4"])
    assert User.find(1).graph_neighbors(:distance => 2) == Set.new(["User:1", "User:2", "User:3"])
  end

  test "graph_neighbors_ranked" do
    assert User.find(1).graph_neighbors_ranked(:distance => 2) == [[2, "User:2"], [2, "User:1"], [1, "User:3"]]
  end

  test "graph_edge_from :on" do
    class BlahSave < ActiveRecord::Base
      graph_edge_from self
    end
    assert BlahSave.after_save_callback_chain.map(&:method).include? :store_graph_edge
    assert !(BlahSave.after_create_callback_chain.map(&:method).include? :store_graph_edge)
    assert !(BlahSave.after_update_callback_chain.map(&:method).include? :store_graph_edge)
    class BlahCreate < ActiveRecord::Base
      graph_edge_from self, :on => :create
    end
    assert BlahCreate.after_create_callback_chain.map(&:method).include? :store_graph_edge
    assert !(BlahCreate.after_save_callback_chain.map(&:method).include? :store_graph_edge)
    assert !(BlahCreate.after_update_callback_chain.map(&:method).include? :store_graph_edge)
    class BlahUpdate < ActiveRecord::Base
      graph_edge_from self, :on => :update
    end
    assert BlahUpdate.after_update_callback_chain.map(&:method).include? :store_graph_edge
    assert !(BlahUpdate.after_save_callback_chain.map(&:method).include? :store_graph_edge)
    assert !(BlahUpdate.after_create_callback_chain.map(&:method).include? :store_graph_edge)
  end

  test "graph_edge_from options" do
    class Blah < ActiveRecord::Base
      graph_edge_from self, :to => :foo_to, :on => :foo_on, :if => :foo_if
    end
    assert (Blah.read_inheritable_attribute(:graph_edge_from_directives)[0].options ==
            {:to => :foo_to, :on => :foo_on, :if => :foo_if})
    assert_raise ArgumentError do
      class Blah < ActiveRecord::Base
        graph_edge_from self, :foo => :bar
      end
    end
  end

end
