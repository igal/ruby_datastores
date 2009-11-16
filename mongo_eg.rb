#!/usr/bin/env ruby

require 'rubygems'
require 'mongo' # Using mongo 0.16 driver from GemCutter

#---[ Data structures ]-------------------------------------------------

categories = [
  { :_id => 1, :title => "Work" },
  { :_id => 2, :title => "Play" },
]

tasks = [
  { :_id => 1, :title => "Finish project", :category_id => 1 },
  { :_id => 2, :title => "Send invoice", :category_id => 1 },
  { :_id => 3, :title => "Go to beach", :category_id => 2 },
  { :_id => 4, :title => "Study esoteric monorails", :category_id => 2 },
]

#---[ Mongo ]-----------------------------------------------------------

# Connect to database
db = Mongo::Connection.new("localhost", 27017).db("mydb")

# Populate categories
category_collection = db.collection("category")
category_collection.remove
categories.each do |category|
  category_collection << category
end

# Populate tasks
task_collection = db.collection("task")
task_collection.remove
tasks.each do |task|
  task_collection << task
end
task_collection.create_index("category_id")

# Find task by id
task = task_collection.find_one(:_id => 1)
puts "* Find a task by id #1: #{task['title']}"

# Find tasks by category
tasks = task_collection.find(:category_id => 1)
puts "* Find tasks by category #1:"
tasks.each do |task|
  puts "  - #{task['title']}"
end

# Find tasks by substring
tasks = task_collection.find(:title => /in/)
puts "* Query tasks matching regexp /in/:"
tasks.each do |task|
  puts "  - #{task['title']}"
end

#---[ Naive benchmarks ]------------------------------------------------

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10_000

benchmark_collection = db.collection("benchmark")
benchmark_collection.create_index("id")

items = []
for i in 0...n
  items << { :id => i, :message => "omgkittens" }
end

benchmark_collection.remove
s = elapsed do
  for i in 0...n
    benchmark_collection << items[i]
  end
  system "sync"
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

benchmark_collection.remove
s = elapsed do
  benchmark_collection.insert(items)
  system "sync"
end
puts "* %i inserts per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

s = elapsed do
  for i in 0...n
    item = benchmark_collection.find_one("id" => i)
    item["id"] == i or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

seen = {}
s = elapsed do
  benchmark_collection.find.each do |item|
    i = item["id"]
    if seen[i]
      raise "Already saw #{i}"
    else
      seen[i] = true
    end
  end
end
puts "* %i retrieves per second as group, for %i items over %0.2f seconds" % [n/s, n, s]


#---[ Teardown ]--------------------------------------------------------

category_collection.remove
task_collection.remove
benchmark_collection.remove

=begin
MRI 1.8.7 with mongo 0.10 driver
* 3316 inserts per second individually, for 10000 items over 3.01 seconds
* 917 inserts per second as group, for 10000 items over 11.36 seconds
* 1375 retrieves per second individually, for 10000 items over 7.27 seconds
* 7725 retrieves per second as group, for 10000 items over 1.29 seconds

JRuby 1.3.1 with mongo 0.10 driver
* 3892 inserts per second individually, for 10000 items over 2.57 seconds
* 7158 inserts per second as group, for 10000 items over 1.40 seconds
* 1845 retrieves per second individually, for 10000 items over 5.42 seconds
* 6963 retrieves per second as group, for 10000 items over 1.44 seconds

JRuby 1.4.0 with mongo 0.10 driver
* 4366 inserts per second individually, for 10000 items over 2.29 seconds
* 1680 retrieves per second individually, for 10000 items over 5.95 seconds

...

MRI 1.8.7 with mongo 0.16 driver
* 2376 inserts per second individually, for 10000 items over 4.21 seconds
* 1018 inserts per second as group, for 10000 items over 10.12 seconds
* 1049 retrieves per second individually, for 10000 items over 9.53 seconds
* 3458 retrieves per second as group, for 10000 items over 2.89 seconds

JRuby 1.4.0 with mongo 0.16 driver
* 2374 inserts per second individually, for 10000 items over 4.21 seconds
* 8928 inserts per second as group, for 10000 items over 1.12 seconds
* 1819 retrieves per second individually, for 10000 items over 5.49 seconds
* 6116 retrieves per second as group, for 10000 items over 1.63 seconds

...

MRI 1.8.7 with mongo 0.16 driver with C extensions
* 3853 inserts per second individually, for 10000 items over 2.60 seconds
* 1157 inserts per second as group, for 10000 items over 8.64 seconds
* 1329 retrieves per second individually, for 10000 items over 7.52 seconds
* 6955 retrieves per second as group, for 10000 items over 1.44 seconds
=end
