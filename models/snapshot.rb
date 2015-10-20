class Snapshot < ActiveRecord::Base
  has_many :histories
end
