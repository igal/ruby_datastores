#!/usr/bin/env ruby

require 'rubygems'
require 'couchrest'

#---[ Naive benchmarks ]------------------------------------------------

n = 1000
db = CouchRest.database!("http://127.0.0.1:5984/couchrest-test")

items = []
for i in 0...n
  # FIXME I can't use integers?!
  items << { "_id" => i.to_s, "number" => i.to_s, :message => "omgkittens" }
end

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

def delete_all(db)
  # FIXME Isn't there an easier way to delete everything?
  db.documents['rows'].each do |row|
    doc = db.get(row['id'])
    db.delete_doc(doc, true)
  end
  db.bulk_delete
end
delete_all(db)

delete_all(db)
s = elapsed do
  for i in 0...n
    db.save_doc(items[i])
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I perform a bulk insert? The #bulk_save method throws a cryptic exception.
### db.bulk_delete
### s = elapsed do
###   items.each do |item|
###     db.save_doc(item["_id"], true)
###   end
###   db.bulk_save # FIXME wtf? throws an exception about Fixnums
### end
### puts "* %i inserts per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

s = elapsed do
  for i in 0...n
    item = db.get(i.to_s)
    item["number"] == i.to_s or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves per second by key, for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I retrieve records by the "number" column? Do I have to create a per-lookup view?
### s = elapsed do
###   for i in 0...n
###     item = db.get(i.to_s)
###     item["number"] == i.to_s or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
###   end
### end
### puts "* %i retrieves per second by key, for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I retrieve multiple records at once efficiently?
### seen = {}
### s = elapsed do
###   benchmark_collection.find.each do |item|
###     i = item["id"]
###     if seen[i]
###       raise "Already saw #{i}"
###     else
###       seen[i] = true
###     end
###   end
### end
### puts "* %i retrieves per second as group, for %i items over %0.2f seconds" % [n/s, n, s]
