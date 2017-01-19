class AddSnapshotsOffsiteBase < ActiveRecord::Migration
  def change
    add_column :snapshots, :offsite_base, :boolean
  end
end
