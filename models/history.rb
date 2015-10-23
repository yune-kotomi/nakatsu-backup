class History < ActiveRecord::Base
  belongs_to :path
  belongs_to :disk
  belongs_to :snapshot

  before_save :set_size

  def relative_path
    file_path.sub(File.join(snapshot.path, '/'), '')
  end

  private
  def set_size
    self.size = File.size(file_path)
  end
end
