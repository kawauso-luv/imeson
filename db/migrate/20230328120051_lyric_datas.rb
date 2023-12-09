class LyricDatas < ActiveRecord::Migration[6.1]
  def change
    create_table :lyricdata do |t|
      t.string :song
      t.string :artist
      t.string :lyric
      t.float :bpm
      t.float :likedislike
      t.float :joysad
      t.float :angerfear
      t.float :valence
      t.float :energy
      t.float :danceability
      t.timestamps null: false
    end
  end
end
