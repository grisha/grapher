ActiveRecord::Schema.define(:version => 0) do
  create_table :items, :force => true do |t|
    t.string :name
  end
  create_table :users, :force => true do |t|
    t.string :name
  end
  create_table :orders, :force => true do |t|
    t.integer :user_id
  end
  create_table :order_items, :force => true do |t|
    t.integer :order_id
    t.integer :item_id
  end
#   execute "INSERT INTO test_items (id, name) VALUES (1, 'A')"
#   execute "INSERT INTO test_items (id, name) VALUES (2, 'B')"
#   execute "INSERT INTO test_items (id, name) VALUES (3, 'C')"
#   execute "INSERT INTO test_items (id, name) VALUES (4, 'D')"
#   execute "INSERT INTO test_users (id, name) VALUES (1, 'one')"
#   execute "INSERT INTO test_users (id, name) VALUES (2, 'two')"
#   execute "INSERT INTO test_users (id, name) VALUES (3, 'three')"
#   execute "INSERT INTO test_users (id, name) VALUES (4, 'four')"
#   execute "INSERT INTO test_orders (id, test_user_id) VALUES(1, 1)"
#   execute "INSERT INTO test_orders (id, test_user_id) VALUES(2, 2)"
#   execute "INSERT INTO test_orders (id, test_user_id) VALUES(3, 3)"
#   execute "INSERT INTO test_orders (id, test_user_id) VALUES(4, 4)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (1, 1)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (1, 4)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (2, 1)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (2, 2)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (2, 4)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (3, 1)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (3, 3)"
#   execute "INSERT INTO test_order_items (test_order_id, test_item_id) VALUES (4, 3)"
end


