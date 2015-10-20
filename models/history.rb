class History < ActiveRecord::Base
  belongs_to :path
  belongs_to :disk
  belongs_to :snapshot

  before_save :set_size

  private
  def set_size
    self.size = File.size(file_path)
  end
end
