class CreatePaths < ActiveRecord::Migration
  def change
    create_table :paths do |t|
      t.string :path # 実体のパス

      t.timestamps null: false
    end
    add_index :paths, :path
  end
end
