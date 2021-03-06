require "./package"

class PackedParser
  def initialize(**options)
    @skip_md5 = options[:skip_md5]
    @skip_pgp = options[:skip_pgp]
    @var_int = options[:var_int] # variable length integer encoding
  end

  def dump_string(io, str)
    unless str.nil?
      raise unless str.instance_of? String
      io.write(str)
    end
    # string is null-terminated and it makes its handling easier in C
    # another storage option is to have 'i8(stringsize) + string.data'
    # that makes scanning faster but requires string dup() in C code to convert
    # one to NUL-terminated.
    io.write("\0")
  end

  # the same as dump_string but no trailing NUL
  # used for data with predefined length
  def dump_binary(io, data, length)
    raise if data.length != length
    io.write(data)
  end

  def dump_varint(io, i)
    # Variable length integer encoding, similar to one used by ProtoBuffer
    loop do
      rem = i % 0x80
      i = i / 0x80
      rem |= 0x80 if i > 0 # set MSB bit to 1 if more symbols are coming
      io.putc(rem)
      break if i == 0
    end
  end

  def dump_u8(io, int)
    if @var_int
      dump_varint(io, int)
    else
      bin = [int].pack("C") # 8-bit unsigned
      dump_binary(io, bin, 1)
    end
  end

  def dump_u32(io, int)
    if @var_int
      dump_varint(io, int)
    else
      bin = [int].pack("L") # 32-bit unsigned, native (!!) endian
      dump_binary(io, bin, 4)
    end
  end

  def dump_u64(io, int)
    if @var_int
      dump_varint(io, int)
    else
      bin = [int].pack("Q") # 64-bit unsigned, native (!!) endian
      dump_binary(io, bin, 8)
    end
  end

  # array can have up to 255 elements
  def dump_array_str(io, arr)
    if arr.nil?
      dump_u8(io, 0)
    else
      dump_u8(io, arr.size)
      arr.each { dump_string(io, _1) }
    end
  end

  def dump(io, pkg)
    dump_string(io, pkg.filename)
    dump_string(io, pkg.name)
    dump_string(io, pkg.base)
    dump_string(io, pkg.version)
    dump_string(io, pkg.description)
    dump_array_str(io, pkg.groups)
    dump_u64(io, pkg.download_size)
    dump_u64(io, pkg.install_size)
    dump_binary(io, pkg.md5sum, 16) unless @skip_md5
    dump_binary(io, pkg.sha256sum, 32)
    dump_string(io, pkg.pgpsig) unless @skip_pgp
    dump_string(io, pkg.url)
    dump_array_str(io, pkg.license)
    dump_string(io, pkg.arch)
    dump_u64(io, pkg.builddate)
    dump_string(io, pkg.packager)
    dump_array_str(io, pkg.replaces)
    dump_array_str(io, pkg.conflicts)
    dump_array_str(io, pkg.provides)
    dump_array_str(io, pkg.depends)
    dump_array_str(io, pkg.optdepends)
    dump_array_str(io, pkg.makedepends)
    dump_array_str(io, pkg.checkdepends)
  end

  def parse_binary(io, len)
    io.read(len)
  end

  def parse_string(io)
    io.readline("\0")[0..-2]
  end

  def parse_array_str(io)
    len = parse_u8(io)
    len.times.map { parse_string(io) }
  end

  def parse_varint(io)
    i = 0
    offset = 0
    lastbyte = false
    loop do
      c = io.getbyte
      if c >= 0x80
        c &= 0x7f # remove the MSB that indicates that more symbols are coming
      else
        lastbyte = true
      end

      c <<= offset
      i += c
      return i if lastbyte

      offset += 7
    end
  end

  def parse_u8(io)
    if @var_int
      parse_varint(io)
    else
      io.read(1).unpack("C")[0]
    end
  end

  def parse_u32(io)
    if @var_int
      parse_varint(io)
    else
      io.read(4).unpack("L")[0]
    end
  end

  def parse_u64(io)
    if @var_int
      parse_varint(io)
    else
      io.read(8).unpack("Q")[0]
    end
  end

  def parse(io)
    pkg = Package.new

    pkg.filename = parse_string(io)
    pkg.name = parse_string(io)
    pkg.base = parse_string(io)
    pkg.version = parse_string(io)
    pkg.description = parse_string(io)
    pkg.groups = parse_array_str(io)
    pkg.download_size = parse_u64(io)
    pkg.install_size = parse_u64(io)
    pkg.md5sum = parse_binary(io, 16) unless @skip_md5
    pkg.sha256sum = parse_binary(io, 32)
    pkg.pgpsig = parse_string(io) unless @skip_pgp
    pkg.url = parse_string(io)
    pkg.license = parse_array_str(io)
    pkg.arch = parse_string(io)
    pkg.builddate = parse_u64(io)
    pkg.packager = parse_string(io)
    pkg.replaces = parse_array_str(io)
    pkg.conflicts = parse_array_str(io)
    pkg.provides = parse_array_str(io)
    pkg.depends = parse_array_str(io)
    pkg.optdepends = parse_array_str(io)
    pkg.makedepends = parse_array_str(io)
    pkg.checkdepends = parse_array_str(io)

    pkg
  end
end

class PackedStorage
  def initialize(filename, **options)
    @filename = filename
    @parser = PackedParser.new(**options)
  end

  # Returns object of type Database
  def load
    db = Database.new
    File.open(@filename) do |file|
      while not file.eof?
        db.packages << @parser.parse(file)
      end
    end
    db
  end

  def store(db)
    File.open(@filename, "wb") do |w|
      db.packages.each do
        @parser.dump(w, _1)
      end
    end
  end
end
