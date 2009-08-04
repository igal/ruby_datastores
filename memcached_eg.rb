#!/usr/bin/env ruby

require 'rubygems'
require 'memcache'

#---[ Naive benchmarks ]------------------------------------------------

n = 10000
db = MemCache.new('localhost:11211')

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

items = []
for i in 0...n
  items << { :id => i, :message => "omgkittens" }
end

db.flush_all
s = elapsed do
  for i in 0...n
    db[i.to_s] = items[i]
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

s = elapsed do
  for i in 0...n
    item = db[i.to_s]
    item[:id] == i or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

=begin
* 3293 inserts per second individually, for 10000 items over 3.04 seconds
* 1438 retrieves per second individually, for 10000 items over 6.95 seconds
=end
