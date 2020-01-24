#!/usr/bin/ruby

require "./packed"

parser = PackedParser.new

# a number of predefined samples and then a bunch of random numbers
samples = [0, 1, 2, 127, 128, 129, 255, 256, 1000, 4096, 33556677889900, 8823088] + Array.new(40000) { rand(0...100000000000000000) }

TESTFILE = "/tmp/varint_test"

File.open(TESTFILE, "w") do |io|
  samples.each { parser.dump_varint(io, _1) }
end

File.open(TESTFILE) do |io|
  samples.each_with_index do
    i = parser.parse_varint(io)
    raise "#{_2}-th sample differs: #{_1} vs #{i}" if _1 != i
  end

  raise "Expected to reach EOF" unless io.eof?
end
