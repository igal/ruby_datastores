#!/usr/bin/env ruby

system %{echo "drop table if exists bench; create table bench ( id INTEGER PRIMARY KEY, number INTEGER, message VARCHAR(64)); create unique index bench_idx on bench(number);" | sqlite3 test.sqlite3}

DSN = 'DBI:Sqlite3:test.sqlite3'

require 'rubygems'
require 'dbi'

#---[ Naive benchmarks ]------------------------------------------------

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 1000

dbh = DBI.connect(DSN)

dbh.do 'delete from bench'
sth = dbh.prepare 'insert into bench (number, message) values (?, ?)'
s = elapsed do
  for i in 0...n
    sth.execute i, 'omgkittens'
  end
end
puts "* %i inserts per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

dbh.do 'delete from bench'
dbh.execute 'begin'
sth = dbh.prepare 'insert into bench (number, message) values (?, ?)'
s = elapsed do
  for i in 0...n
    sth.execute i, 'omgkittens'
  end
end
dbh.execute 'commit'
puts "* %i inserts per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

sth = dbh.prepare 'select * from bench where number = ?'
s = elapsed do
  for i in 0...n
    sth.execute(i)
    item = sth.fetch_hash
    item["number"] == i or raise "Mismatch! Expected #{i}, got: #{item.inspect}"
  end
end
puts "* %i retrieves per second individually, for %i items over %0.2f seconds" % [n/s, n, s]

seen = {}
s = elapsed do
  dbh.select_all('select * from bench').each do |item|
    i = item["number"]
    if seen[i]
      raise "Already saw #{i}"
    else
      seen[i] = true
    end
  end
end
puts "* %i retrieves per second as group, for %i items over %0.2f seconds" % [n/s, n, s]

=begin
* 71 inserts per second individually, for 1000 items over 13.94 seconds
* 7880 inserts per second as group, for 1000 items over 0.13 seconds
* 3543 retrieves per second individually, for 1000 items over 0.28 seconds
* 8973 retrieves per second as group, for 1000 items over 0.11 seconds
=end
