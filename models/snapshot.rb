class Snapshot < ActiveRecord::Base
  has_many :histories

  def name
    File.basename(path)
  end
end
