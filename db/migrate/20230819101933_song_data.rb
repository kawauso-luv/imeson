class SongData < ActiveRecord::Migration[6.1]
  def change
    create_table :genredata do |t|
      t.integer :lyricdata_id
      t.string :genre
    end
  end
end
