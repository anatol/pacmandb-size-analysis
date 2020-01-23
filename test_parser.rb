#!/usr/bin/ruby

require "./package"
require "./plaintext"
require "./packed"

db = PlainTextStorage.new("data/db.plain").load
PackedStorage.new("data/db.packed_test_parser").store(db)

db = PackedStorage.new("data/db.packed_test_parser").load
PlainTextStorage.new("data/db.plain_test_parser").store(db)

raise "Conversion plain->packed->plain does not produce results identical to original" unless FileUtils.identical?("data/db.plain", "data/db.plain_test_parser")
# diff -C 6 --color <(tar -xOf data/db) <(tar -xOf data/db.plain)`