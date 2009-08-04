#!/usr/bin/env ruby

require 'rubygems'
require 'mongo'

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
db = XGen::Mongo::Driver::Mongo.new("localhost", 27017).db("mydb")

# Populate categories
category_collection = db.collection("category")
category_collection.drop
categories.each do |category|
  category_collection << category
end

# Populate tasks
task_collection = db.collection("task")
task_collection.drop
tasks.each do |task|
  task_collection << task
end
task_collection.create_index("category_id")

# Find task by id
task = task_collection.find_first(:_id => 1)
p task

# Find tasks by category
tasks = task_collection.find(:category_id => 1)
p tasks.to_a

# Find tasks by substring
tasks = task_collection.find(:title => /in/)
p tasks.to_a

#---[ Naive benchmarks ]------------------------------------------------

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10000

benchmark_collection = db.collection("benchmark")
benchmark_collection.create_index("id")

items = []
for i in 0...n
  items << { :id => i, :message => "omgkittens" }
end

benchmark_collection.clear
s = elapsed do
  for i in 0...n
    benchmark_collection << items[i]
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

benchmark_collection.clear
s = elapsed do
  benchmark_collection.insert(items)
end
puts "* %i inserts per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

s = elapsed do
  for i in 0...n
    item = benchmark_collection.find_first("id" => i)
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

=begin
MRI 1.8.7
* 3316 inserts per second individually, for 10000 items over 3.01 seconds
* 917 inserts per second as group, for 10000 items over 11.36 seconds
* 1375 retrieves per second individually, for 10000 items over 7.27 seconds
* 7725 retrieves per second as group, for 10000 items over 1.29 seconds

JRuby 1.3.1
* 3892 inserts per second individually, for 10000 items over 2.57 seconds
* 7158 inserts per second as group, for 10000 items over 1.40 seconds
* 1845 retrieves per second individually, for 10000 items over 5.42 seconds
* 6963 retrieves per second as group, for 10000 items over 1.44 seconds
=end
