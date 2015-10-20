class CreateHistories < ActiveRecord::Migration
  def change
    create_table :histories do |t|
      t.string :file_path # スナップショットのベースパスからの相対パス
      t.column :size, :bigint

      t.integer :disk_id
      t.integer :path_id
      t.integer :snapshot_id

      t.timestamps null: false
    end
    add_index :histories, :file_path
  end
end
