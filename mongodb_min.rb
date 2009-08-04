#!/usr/bin/env ruby
require 'rubygems'

require 'mongo'

# Connect.
db = XGen::Mongo::Driver::Mongo.new("localhost", 27017).db("mydb")

# Get a collection.
collection = db.collection("mycollection")

# Add an index.
collection.create_index("number")

# Insert an item.
collection << { :number => 1, :message => "Hello" }

# Retrieve an item.
p collection.find_first(:number => 1)

# Query items.
p collection.find(:message => /ello/).to_a
