require "json"
class EmotionanalyzerApi
    class << self
        def analyze(usertext, selected_genre)
            uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
            uri.query = URI.encode_www_form({
                :out => "json",
                :apikey => ENV["FEELING_API_KEY"],
                :text => usertext
            })
            response = Net::HTTP.get_response(uri)
            json = JSON.parse(response.body)
            @usertext_api=[]
            @usertext_api[0] = json["likedislike"]
            @usertext_api[1] = json["joysad"]
            @usertext_api[2] = json["angerfear"]
            
            puts @usertext_api
            
            
            #一番感情分析結果が近いものを見つける
            selected_genre_song = Genredata.where(genre: selected_genre)
            #likeが+で、angが絶対値0.5以下なら、valenceが0.7以上の曲から選ぶ
            if @usertext_api[0].to_f>0 and @usertext_api[2].to_f<0.5
                selected_genre_song.each do |i|
                    i = Lyricdata.find(i.lyricdata_id)
                    if i.valence == 0.7..1 
                        selected_genre_song.push(i)
                    end
                end
            end
            if selected_genre_song == nil
                selected_genre_song = Genredata
            end
            result = 0
            min = 100000
            selected_genre_song.each do |aaa|
                i = Lyricdata.find(aaa.lyricdata_id)
                like = i.likedislike.to_f - @usertext_api[0].to_f
                joy = i.joysad.to_f - @usertext_api[1].to_f
                ang = i.angerfear.to_f - @usertext_api[2].to_f
                result = like**2 + joy**2 + ang**2
                result = Math.sqrt(result)
                if min > result
                    min = result.abs
                    @artist = i.artist
                    @song = i.song
                    @lyric = i.lyric
                end
            end
            
            data = {
                usertext_api: @usertext_api,
                artist: @artist,
                song: @song,
                lyric: @lyric
            }
            
            return data
        end
    end
end