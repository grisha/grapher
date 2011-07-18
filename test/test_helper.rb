ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'rubygems'
require 'test/unit'
require 'redis'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

require 'active_support'
require 'active_support/test_case'

class Item < ActiveRecord::Base
end

class User < ActiveRecord::Base
  has_many :rders
end

class Order < ActiveRecord::Base
  belongs_to :user
  has_many :items, :through => :order_items
end

class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :item
  has_one :user, :through => :order
  graph_edge_from :user, :to => :item, :verb => 'Purchased'
end


def load_schema
  config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
  ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")

  db_adapter = ENV['DB']

  # no db passed, try one of these fine config-free DBs before bombing.
  db_adapter ||=
    begin
      require 'rubygems'
      require 'sqlite'
      'sqlite'
    rescue MissingSourceFile
      begin
        require 'sqlite3'
        'sqlite3'
      rescue MissingSourceFile
      end
    end

  if db_adapter.nil?
    raise "No DB Adapter selected. Pass the DB= option to pick one, or install Sqlite or Sqlite3."
  end

  ActiveRecord::Base.establish_connection(config[db_adapter])
  load(File.dirname(__FILE__) + "/schema.rb")
  #require File.dirname(__FILE__) + '/../rails/init'
end

def load_data
  $redis = Redis.new
  $redis.select 13
  user_one = User.create(:name => 'one')
  user_two = User.create(:name => 'two')
  user_three = User.create(:name => 'three')
  user_four = User.create(:name => 'four')
  item_a = Item.create(:name => 'A')
  item_b = Item.create(:name => 'B')
  item_c = Item.create(:name => 'C')
  item_d = Item.create(:name => 'D')
  order_1 = Order.create(:user => user_one)
  order_2 = Order.create(:user => user_two)
  order_3 = Order.create(:user => user_three)
  order_4 = Order.create(:user => user_four)
  OrderItem.create(:order => order_1, :item => item_a)
  OrderItem.create(:order => order_1, :item => item_d)
  OrderItem.create(:order => order_2, :item => item_a)
  OrderItem.create(:order => order_2, :item => item_b)
  OrderItem.create(:order => order_2, :item => item_d)
  OrderItem.create(:order => order_3, :item => item_a)
  OrderItem.create(:order => order_3, :item => item_c)
  OrderItem.create(:order => order_4, :item => item_c)
end
