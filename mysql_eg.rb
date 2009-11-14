#!/usr/bin/env ruby

#---[ Setup ]-----------------------------------------------------------

# InnoDB
## system %{echo "drop database if exists test; create database test; use test; create table bench ( id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), number INT, message VARCHAR(64)) ENGINE=InnoDB; create unique index bench_idx on bench(number);" | mysql}
# MyISAM
system %{echo "drop database if exists test; create database test; use test; create table bench ( id INT NOT NULL AUTO_INCREMENT, PRIMARY KEY(id), number INT, message VARCHAR(64)) ENGINE=MyISAM; create unique index bench_idx on bench(number);" | mysql}

USER = 'igal'
PASS = ''
DSN = 'DBI:Mysql:test'

require 'rubygems'
require 'dbi'

dbh = DBI.connect(DSN, USER, PASS)

#---[ Naive benchmarks ]------------------------------------------------

def elapsed(&block)
  timer = Time.now
  block.call
  return Time.now - timer
end

n = 10000

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

#---[ Teardown ]--------------------------------------------------------

system %{echo "drop database test;" | mysql}

=begin
MySQL 5.0 with MyISAM
* 6488 inserts per second individually, for 10000 items over 1.54 seconds
* 1178 retrieves per second individually, for 10000 items over 8.49 seconds
* 5524 inserts per second as group, for 10000 items over 1.81 seconds
* 19549 retrieves per second as group, for 10000 items over 0.51 seconds

MySQL 5.0 with InnoDB, much slower inserts
* 765 inserts per second individually, for 10000 items over 13.07 seconds
* 1113 retrieves per second individually, for 10000 items over 8.98 seconds
* 4392 inserts per second as group, for 10000 items over 2.28 seconds
* 18192 retrieves per second as group, for 10000 items over 0.55 seconds
=end
