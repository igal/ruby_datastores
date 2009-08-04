#!/usr/bin/env ruby
require 'rubygems'

require 'couchrest'

# Connect.
db = CouchRest.database!("http://127.0.0.1:5984/couchrest-test")

# Add an view.
db.delete_doc db.get("_design/queries") rescue nil
db.save_doc({
  "_id" => "_design/queries",
  :views => {
    :by_number => {
      :map => "function(doc) {
        if (doc.number) {
          emit(doc.number, doc);
        }
      }"
    }
  }
})

# Insert an item.
db.save_doc("_id" => "foo", "number" => 1, "message" => "Hello") rescue nil

# Retrieve an item.
p db.get("foo")

# Query items.
p db.view("queries/by_number", :key => 1)["rows"].map{|row| row["value"]}
