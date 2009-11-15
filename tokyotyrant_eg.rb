#!/usr/bin/env ruby

# Startup:
### ttserver omg.tct#bnum=1000000

require 'rubygems'
require 'rufus/tokyo/tyrant'

#---[ Work ]------------------------------------------------------------

db = Rufus::Tokyo::TyrantTable.new('localhost', 1978)

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10_000

items = []
for i in 0...n
  items << { :id => i, :message => "omgkittens" }
end

db.clear
s = elapsed do
  for i in 0...n
    db[i] = items[i]
  end
  system "sync"
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
n=10_000
* 6381 inserts per second individually, for 10000 items over 1.57 seconds
* 5647 retrieves by key per second individually, for 10000 items over 1.77 seconds
* 2128 retrieves by field per second individually, for 10000 items over 4.70 seconds
* 3274 retrieves per second as group, for 10000 items over 3.05 seconds

n=100_000
* 6139 inserts per second individually, for 100000 items over 16.29 seconds
* 5708 retrieves by key per second individually, for 100000 items over 17.52 seconds
* 2213 retrieves by field per second individually, for 100000 items over 45.18 seconds
* 3242 retrieves per second as group, for 100000 items over 30.84 seconds
=end
