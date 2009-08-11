#!/usr/bin/env ruby

# Startup:
### ttserver omg.tct

require 'rubygems'
require 'rufus/tokyo/tyrant'

#---[ Work ]------------------------------------------------------------

db = Rufus::Tokyo::TyrantTable.new('localhost', 1978)

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10000

items = []
for i in 0...n
  items << { :id => i, :message => "omgkittens" }
end

db.clear
s = elapsed do
  for i in 0...n
    db[i] = items[i]
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

s = elapsed do
  for i in 0...n
    item = db[i.to_s]
    item["id"] == i.to_s or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves by key per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

db.set_index('id', :decimal)

s = elapsed do
  for i in 0...n
    item = db.query do |query|
      query.add_condition 'id', :numeq, i.to_s
      query.limit(1)
    end.first
    item["id"] == i.to_s or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves by field per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

seen = {}
s = elapsed do
  db.each do |key, item|
    i = item["id"].to_i
    if seen[i]
      raise "Already saw #{i}"
    else
      seen[i] = true
    end
  end
end
puts "* %i retrieves per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

=begin
* 6204 inserts per second individually, for 10000 items over 1.38 seconds
* 5787 retrieves by key per second individually, for 10000 items over 1.52 seconds
* 196 retrieves by field per second individually, for 10000 items over 51.00 seconds
* 3882 retrieves per second as group, for 10000 items over 2.42 seconds
=end
