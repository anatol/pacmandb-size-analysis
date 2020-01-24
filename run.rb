#!/usr/bin/ruby

require "fileutils"

require "./package"
require "./plaintext"
require "./packed"

def compress(name)
  `zstd -q -19 -T0 data/db.#{name} -o data/db.#{name}.zstd`
end

def compare(old, new)
  case
  when old == new
    "equal to"
  when old > new
    "#{old.to_f / new} times better than"
  when old < new
    "#{new.to_f / old} times worse than"
  else
    raise
  end
end

def experiment(name, sample, storage, **options)
  filename = "data/db.#{name}"
  storage.new(filename, **options).store(sample)
  compress(name)

  original_size = File.size("data/db.original")
  original_zstd_size = File.size("data/db.original.zstd")

  size = File.size(filename)
  zstd_size = File.size(filename + ".zstd")

  puts "Experiment '#{name}':"
  puts "  uncompressed size is #{size} that is " + compare(original_size, size) + " original sample"
  puts "  'zstd -19' compressed size is #{zstd_size} that is " + compare(original_zstd_size, zstd_size) + " original sample"
end

if File.exists?("data")
  puts "Remove old 'data' directory"
  FileUtils.rm_rf("data")
end

FileUtils.mkdir("data")
puts "Use copy of /var/lib/pacman/sync/community.db as a sample for experiments"
`gzip -c -d /var/lib/pacman/sync/community.db > data/db.original`

db = PlainTextStorage.new("data/db.original").load
# compress original file for the future comparisons
compress("original")

experiment("plain", db, PlainTextStorage)
# this new .plain file should have identical content to the original sample
content1 = `tar -xOf data/db.original`
content2 = `tar -xOf data/db.plain`
raise "Generated .plain file differs in content from the original sample" if content1 != content2
# The same check running from shell
#   diff -C 6 --color <(tar -xOf data/db) <(tar -xOf data/db.plain)`

# More experiments with plain text format
experiment("plain_nomd5", db, PlainTextStorage, :skip_md5 => true)
experiment("plain_nopgp", db, PlainTextStorage, :skip_pgp => true)
experiment("plain_nomd5pgp", db, PlainTextStorage, :skip_md5 => true, :skip_pgp => true)

# And now our new and shiny packed format
experiment("packed", db, PackedStorage)
experiment("packed_nomd5", db, PackedStorage, :skip_md5 => true)
experiment("packed_nopgp", db, PackedStorage, :skip_pgp => true)
experiment("packed_nomd5pgp", db, PackedStorage, :skip_md5 => true, :skip_pgp => true)
experiment("packed_varint_nomd5pgp", db, PackedStorage, :skip_md5 => true, :skip_pgp => true, :var_int => true)
