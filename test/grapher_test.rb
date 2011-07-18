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

end
