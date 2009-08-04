#!/usr/bin/env ruby
require 'rubygems'

require 'rufus/tokyo/tyrant'

# Connect.
db = Rufus::Tokyo::TyrantTable.new('localhost', 1978)

# Insert an item.
db["foo"] = { "number" => "1", "message" => "Hello" }

# Retrieve an item.
p db["foo"]

# Query items.
p db.query do |q|
  q.add_condition("message", :includes, "ello")
  q.limit(5)
end
