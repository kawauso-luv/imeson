class LyricDatas < ActiveRecord::Migration[6.1]
  def change
    create_table :lyricdata do |t|
      t.string :song
      t.string :artist
      t.string :lyric
      t.string :genre
      t.float :bpm
      t.float :likedislike
      t.float :joysad
      t.float :angerfear
      t.timestamps null: false
    end
  end
end
