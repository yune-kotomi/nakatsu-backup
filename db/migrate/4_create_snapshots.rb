class CreateSnapshots < ActiveRecord::Migration
  def change
    create_table :snapshots do |t|
      t.string :path

      t.timestamps null: false
    end
    add_index :snapshots, :path
  end
end
