class AddHistoriesDigestIndex < ActiveRecord::Migration
  def change
    add_index :histories, :digest
  end
end
