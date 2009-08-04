#!/usr/bin/env ruby

system %{dropdb test; createdb test; echo "drop table bench; drop index bench_idx; drop sequence bench_seq; create sequence bench_seq; create table bench ( id integer PRIMARY KEY DEFAULT nextval('bench_seq'), number integer, message varchar(64)); create unique index bench_idx on bench(number);" | psql test}


USER = 'igal'
PASS = 'igal'
DSN = 'DBI:Pg:test'

require 'rubygems'
require 'dbi'

#---[ Naive benchmarks ]------------------------------------------------

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10000

dbh = DBI.connect(DSN, USER, PASS)

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
* 6488 inserts per second individually, for 10000 items over 1.54 seconds
* 1178 retrieves per second individually, for 10000 items over 8.49 seconds
* 18852 retrieves per second as group, for 10000 items over 0.58 seconds
=end
