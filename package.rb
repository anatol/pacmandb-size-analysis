class Package
  attr_accessor :filename # string
  attr_accessor :name # string
  attr_accessor :base # string
  attr_accessor :version # string
  attr_accessor :description # string
  attr_accessor :groups # Array of string
  attr_accessor :download_size # int
  attr_accessor :install_size # int
  attr_accessor :md5sum # 16 bytes
  attr_accessor :sha256sum # 32 bytes
  attr_accessor :pgpsig # string
  attr_accessor :url # string
  attr_accessor :license # Array of string
  attr_accessor :arch # string
  attr_accessor :builddate # int
  attr_accessor :packager # string
  attr_accessor :depends # Array of string
  attr_accessor :optdepends # Array of string
  attr_accessor :makedepends # Array of string
  attr_accessor :checkdepends # Array of string
  attr_accessor :conflicts # Array of string
  attr_accessor :provides # Array of string
  attr_accessor :replaces # Array of string
end

class Database
  attr :packages # Package[]

  def initialize
    @packages = []
  end
end
