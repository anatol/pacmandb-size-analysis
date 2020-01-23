require "minitar"
require "./package"

class PlainTextParser
  def initialize(**options)
    @skip_md5 = options[:skip_md5]
    @skip_pgp = options[:skip_pgp]
  end

  def parse(str)
    pkg = Package.new

    fields = str.split("\n\n")
    fields.each do |f|
      lines = f.split("\n")
      name = lines.shift

      case name
      when "%NAME%"
        pkg.name = lines.shift
      when "%FILENAME%"
        pkg.filename = lines.shift
      when "%BASE%"
        pkg.base = lines.shift
      when "%VERSION%"
        pkg.version = lines.shift
      when "%DESC%"
        pkg.description = lines.shift
      when "%CSIZE%"
        pkg.download_size = Integer(lines.shift)
      when "%ISIZE%"
        pkg.install_size = Integer(lines.shift)
      when "%MD5SUM%"
        pkg.md5sum = [lines.shift].pack("H*") # convert from hex string to binary
        raise if pkg.md5sum.size != 16
      when "%SHA256SUM%"
        pkg.sha256sum = [lines.shift].pack("H*") # convert from hex string to binary
        raise if pkg.sha256sum.size != 32
      when "%PGPSIG%"
        pkg.pgpsig = lines.shift
      when "%URL%"
        pkg.url = lines.shift
      when "%LICENSE%"
        pkg.license = lines
        lines = []
      when "%ARCH%"
        pkg.arch = lines.shift
      when "%BUILDDATE%"
        pkg.builddate = Integer(lines.shift)
      when "%PACKAGER%"
        pkg.packager = lines.shift
      when "%DEPENDS%"
        pkg.depends = lines
        lines = []
      when "%OPTDEPENDS%"
        pkg.optdepends = lines
        lines = []
      when "%MAKEDEPENDS%"
        pkg.makedepends = lines
        lines = []
      when "%CHECKDEPENDS%"
        pkg.checkdepends = lines
        lines = []
      when "%CONFLICTS%"
        pkg.conflicts = lines
        lines = []
      when "%PROVIDES%"
        pkg.provides = lines
        lines = []
      when "%REPLACES%"
        pkg.replaces = lines
        lines = []
      when "%GROUPS%"
        pkg.groups = lines
        lines = []
      else
        raise "Unknown field #{name}"
      end
      raise "Unhandled lines #{lines}" unless lines.empty?
    end

    pkg
  end

  # return string
  def dump(pkg)
    fields = []

    fields << ["%FILENAME%", pkg.filename].join("\n")
    fields << ["%NAME%", pkg.name].join("\n")
    if pkg.base and not pkg.base.empty?
      fields << ["%BASE%", pkg.base].join("\n")
    end
    fields << ["%VERSION%", pkg.version].join("\n")
    fields << ["%DESC%", pkg.description].join("\n")
    if pkg.groups and not pkg.groups.empty?
      fields << ["%GROUPS%", *pkg.groups].join("\n")
    end
    fields << ["%CSIZE%", pkg.download_size.to_s].join("\n")
    fields << ["%ISIZE%", pkg.install_size.to_s].join("\n")
    unless @skip_md5
      fields << ["%MD5SUM%", pkg.md5sum.unpack("H*").first].join("\n")
    end
    fields << ["%SHA256SUM%", pkg.sha256sum.unpack("H*").first].join("\n")
    unless @skip_pgp
      fields << ["%PGPSIG%", pkg.pgpsig].join("\n")
    end
    if pkg.url and not pkg.url.empty?
      fields << ["%URL%", pkg.url].join("\n")
    end
    if pkg.license and not pkg.license.empty?
      fields << ["%LICENSE%", *pkg.license].join("\n")
    end
    fields << ["%ARCH%", pkg.arch].join("\n")
    fields << ["%BUILDDATE%", pkg.builddate.to_s].join("\n")
    fields << ["%PACKAGER%", pkg.packager].join("\n")
    if pkg.replaces and not pkg.replaces.empty?
      fields << ["%REPLACES%", *pkg.replaces].join("\n")
    end
    if pkg.conflicts and not pkg.conflicts.empty?
      fields << ["%CONFLICTS%", *pkg.conflicts].join("\n")
    end
    if pkg.provides and not pkg.provides.empty?
      fields << ["%PROVIDES%", *pkg.provides].join("\n")
    end
    if pkg.depends and not pkg.depends.empty?
      fields << ["%DEPENDS%", *pkg.depends].join("\n")
    end
    if pkg.optdepends and not pkg.optdepends.empty?
      fields << ["%OPTDEPENDS%", *pkg.optdepends].join("\n")
    end
    if pkg.makedepends and not pkg.makedepends.empty?
      fields << ["%MAKEDEPENDS%", *pkg.makedepends].join("\n")
    end
    if pkg.checkdepends and not pkg.checkdepends.empty?
      fields << ["%CHECKDEPENDS%", *pkg.checkdepends].join("\n")
    end

    fields.join("\n\n") + "\n\n"
  end
end

class PlainTextStorage
  def initialize(tar, **options)
    @tar = tar
    @parser = PlainTextParser.new(**options)
  end

  # Returns object of type Database
  def load
    db = Database.new

    Archive::Tar::Minitar::Reader.each_entry(File.new(@tar)) do |entry|
      next unless entry.name =~ %r{(.*)/desc}
      db.packages << @parser.parse(entry.read)
    end

    db
  end

  def store(db)
    w = Archive::Tar::Minitar::Writer.open(File.new(@tar, "w"))
    db.packages.each do |pkg|
      content = @parser.dump(pkg)
      w.mkdir(pkg.name + "-" + pkg.version + "/")
      w.add_file_simple("#{pkg.name}-#{pkg.version}/desc", :data => content)
    end
    w.close
  end
end

# get content of a tar.gz file:
#   tar -xOzf data/community.db.gz
