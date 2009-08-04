#!/usr/bin/env ruby

require 'rubygems'
require 'couchrest'

#---[ Naive benchmarks ]------------------------------------------------

n = 1000
db = CouchRest.database!("http://127.0.0.1:5984/couchrest-test")

# You must define views in advance to look up documents by properties other
# than '_id'.
#
# This view creates an index of key/value pairs where each document's number
# attribute is a key and that document's data forms the corresponding value.
number_view = {
  :map => "function(doc) {
    if (doc.number) {
      emit(doc.number, doc);
    }
  }"
}

# Design documents are used to store views.
#
# Erase the previous version of the design document if it exists before
# creating the new version.
db.delete_doc db.get("_design/kittens") rescue nil
db.save_doc({
  "_id" => "_design/kittens",
  :views => {
    :number => number_view
  }
})

items = []
for i in 0...n
  # FIXME I can't use integers?!
  #
  # Answer: You can use integers for any field except '_id'.
  items << { "_id" => i.to_s, "number" => i, :message => "omgkittens" }
end

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

def delete_all(db)
  # FIXME Isn't there an easier way to delete everything?
  #
  # Answer: one good way is to drop the database. But then you would lose the
  # design document. Otherwise you have to have a copy of each document's
  # metadata in order to delete it because the document '_id' and '_rev'
  # attributes are required for the delete command. The presence of the '_rev'
  # attribute allows CouchDB to handle conflicts.
  #
  # But at least you don't have to fetch every document twice :)
  db.documents['rows'].each do |row|
    unless row['id'] =~ /^_design/  # Don't delete the design document.
      db.delete_doc({ '_id' => row['id'], '_rev' => row['value']['rev'] }, true)
    end
  end
  db.bulk_delete

  # Verify that everything except the design document was deleted.
  result_set = db.documents
  result_set['total_rows'] == 1 or raise "Expected all documents to be deleted, got #{result_set.inspect}"
end

# individual inserts
delete_all(db)
s = elapsed do
  for i in 0...n
    db.save_doc(items[i])
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I perform a bulk insert? The #bulk_save method throws a cryptic exception.
#
# Answer: an id was passed to `save_doc` where there should have been a document.
delete_all(db)
s = elapsed do
  items.each do |item|
    db.save_doc(item, true)
  end
  db.bulk_save # FIXME wtf? throws an exception about Fixnums
end
puts "* %i inserts per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

# lookups by '_id'
s = elapsed do
  for i in 0...n
    item = db.get(i.to_s)
    item["number"] == i or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves per second by '_id', for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I retrieve records by the "number" column? Do I have to create a per-lookup view?
#
# Answer: you have to create views in advance for any column / key that you
# want to use to perform lookups.  But the value to match with that key and
# other options are provided at query time.
s = elapsed do
  for i in 1...n  # Lookup by number 0 fails. This could be a CouchDB bug.
    result_set = db.view('kittens/number', :key => i)
    if result_set["total_rows"] > 0
      item = result_set["rows"].first["value"]
    else
      item = {}
    end
    item["number"] == i or raise "Mismatch! Expected #{i}, got: #{result_set.inspect}"
  end
end
puts "* %i retrieves per second by 'number', for %i items over %0.2f seconds" % [n/s, n, s]

# FIXME How do I retrieve multiple records at once efficiently?
#
# Answer: compose a query with a key range instead of a single key. Key ranges
# on array keys can be useful for more complicated queries.
#
# If you are using CouchDB 0.9 or later you can also use the all_docs view with
# the 'include_docs' option like this:
#
#     db.documents(:include_docs => true)
#
# That will add a 'doc' key to each returned row. But that method is much less
# efficient than querying a view that alread has all of the document data as
# its values.
result_set = nil
s = elapsed do
  result_set = db.view('kittens/number', :startkey => 0, :endkey => n)
end

expected = (1...n).reduce(0) { |sum, i| sum + i }
actual = result_set['rows'].reduce(0) { |sum, row|
  sum + row['value']['number']
}
actual == expected or raise "Mismatch! Expected #{expected}, got: #{result_set.inspect}"

puts "* %i retrieves per second by 'name' as group, for %i items over %0.2f seconds" % [n/s, n, s]
