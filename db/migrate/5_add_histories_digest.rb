class AddHistoriesDigest < ActiveRecord::Migration
  def change
    add_column :histories, :digest, :string
  end
end
