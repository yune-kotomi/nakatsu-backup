require 'digest/sha2'

class Digest::Base
   def self.open(path)
    obj = new

    File.open(path, 'rb') {|f|
      buf = ""
      while f.read(256, buf)
        obj << buf
      end
    }
    obj
  end
end

class History < ActiveRecord::Base
  belongs_to :path
  belongs_to :disk
  belongs_to :snapshot

  before_save :set_size
  before_save :set_digest

  def relative_path
    file_path.sub(File.join(snapshot.path, '/'), '')
  end

  private
  def set_size
    self.size = File.size(file_path)
  rescue Errno::ENOENT
  end

  def set_digest
    self.digest = Digest::SHA256.open(file_path).hexdigest
  rescue Errno::ENOENT
  end
end
