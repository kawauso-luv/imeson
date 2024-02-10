require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require "net/http"
require "json"
require "nokogiri"
require 'sinatra/activerecord'
require './models'
require 'rspotify'

Dotenv.load

#EmoTune

# 歌詞検索API
def search_songs(q)
    uri = URI.parse("https://api.genius.com/search")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    uri.query = URI.encode_www_form({:q=>q})
    headers = { "Authorization" => "Bearer #{ENV["LYRIC_API"]}" }
    response = http.get(uri, headers)
    json = JSON.parse(response.body)
    
    
    #result = []
    #json["response"]["hits"].each do |song|
    #    next unless song["index"] == "song"
        #別アーティストの諸々を消す
    #    next if song["result"]["artist_names"] == "Genius Japan"
    #    result.push(song["result"])
    #end
    
    #result
    
    
    result = []
    json["response"]["hits"].each do |song|
        next unless song["index"] == "song"
        #別アーティストの諸々を消す
        next if song["result"]["artist_names"] == "Genius Japan"
        result.push(song["result"]["id"])
    end
    
    result
end

def get_lyrics(path)
    uri = URI.parse("https://genius.com" + path)
    p uri
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    response = http.get(uri)
    

    doc = Nokogiri::HTML(response.body)
    
    div = doc.css(".Lyrics__Container-sc-1ynbvzw-1.kUgSbL")
    
    div.search(:b).map &:remove
    div.inner_text.gsub(/\[.*?\]/,"")
    
end

def get_content(q)
    uri = URI.parse("https://api.genius.com/songs/" + q.to_s)
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    uri.query = URI.encode_www_form({:q=>q})
    headers = { "Authorization" => "Bearer #{ENV["LYRIC_API"]}" }
    response = http.get(uri, headers)
    json = JSON.parse(response.body)
    
    
    uri = URI.parse(json["response"]["song"]["url"])
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    response = http.get(uri)
    

    doc = Nokogiri::HTML(response.body)
    
    div = doc.css(".Lyrics__Container-sc-1ynbvzw-1.kUgSbL")
    
    div.search(:b).map &:remove
    div.inner_text.gsub(/\[.*?\]/,"")
end

#歌詞が日本語か判定
def is_japaanese(text) 
    "#{text}" =~ /(?:\p{Hiragana})/
end



get  '/' do
    @usertext_api=[]
    erb :index
end


post '/search' do
    usertext = params[:usertext]
    # 感情分析API
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
    selected_genre = params[:genre]
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
        p "~~~!!~~~!!"
        p result
        if min > result
            min = result.abs
            @artist = i.artist
            @song = i.song
            @lyric = i.lyric
        end
    end
    
    if !@lyric.nil? 
        @lyric = @lyric[0, 10]
    end
    
    erb :index
end

get '/search' do
    erb :index
end

get '/test' do
    p "============="
    ENV['ACCEPT_LANGUAGE'] = "ja"

    RSpotify.authenticate ENV["SPOTIFY_API_1"],ENV["SPOTIFY_API_2"]
    
    #spotifyのプレイリストより曲データ取得
    a = RSpotify::Playlist.find_by_id('5TrSRWLRbWKcZyB8LgcpFr') 
    genre = a.name
    p genre
    genre = "JPOP" if genre =~ /JPOP|J-pop|J-POP/i
    genre = "JROCK" if genre =~ /JROCK|J-rock|J-ROCK/i
    p genre
    #とりあえずの10曲プレイリスト[5TrSRWLRbWKcZyB8LgcpFr]

    
    a.tracks(limit:10).each do |var|
    #いったんfor文作る前に戻した　大丈夫なはず
    #tracks = a.tracks(limit: 5)
    #for song in tracks
        name = var.name()
        song = RSpotify::Track.search(name, market:'JP').first
        #曲の名前
        songname = song.name
        #p songname
        bpm = song.audio_features.tempo
        #p bpm
        #曲のジャンル→曲をつくったアーティストを取得→アーティストのジャンルを登録
        artist_name = song.artists.first.name
        #p artist_name
        
        #spotifyのパラメータたち
        #p "-------------------"
        #ダンスしやすさ +:1.0, -:0.0
        danceability = song.audio_features.danceability
        #エネルギー +:1.0, -:0.0
        energy = song.audio_features.energy
        #曲が伝える音楽のポジティブ性を表す0.0から1.0の尺度。この指数の高い値の曲はより陽性,低い指数の曲はより陰性
        valence = song.audio_features.valence
        #p "~~~~~~~~~~~~~~~~~~~~"
        
        genre = genre
        
        
        #p genre
        
        
        #歌詞検索
        songs = search_songs(songname+" "+artist_name)
        songs.each do |s|
        if s.nil?
        else
            #$lyrics = get_lyrics(s["path"])
            $lyrics = get_content(s)
            puts "~~~~#{$lyrics}~~~~~~~~~"
            
            if is_japaanese($lyrics)
                # @jap = true
                break
            else
                $lyrics = nil
                next
            end
        end
            # if @jap == true
            #     break
            # end    
        end
        
        #p artist_name
        
        #もしまだDBに登録されていなかったら
        if Lyricdata.find_by(song: songname, artist: artist_name).nil?
            #レコードが存在しない場合の処理
            
            unless $lyrics.nil?
            #DBに登録
            @uta = Lyricdata.create(song: songname, bpm: bpm, artist: artist_name, lyric: $lyrics, danceability: danceability, energy: energy, valence: valence)

            utf8 = @uta.lyric
            
            #感情分析API
            uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
            uri.query = URI.encode_www_form({
            :out => "json",
            :apikey => ENV["FEELING_API_KEY"],
            :text => utf8
            })
            response = Net::HTTP.get_response(uri)
            json = JSON.parse(response.body)
            @songtext_api=[]
            @songtext_api[0] = json["likedislike"]
            @songtext_api[1] = json["joysad"]
            @songtext_api[2] = json["angerfear"]
            
            @uta.likedislike = @songtext_api[0]
            @uta.joysad = @songtext_api[1]
            @uta.angerfear = @songtext_api[2]
            @uta.save
            end
        
        end
        
        targetsong = Lyricdata.find_by(song: songname, artist: artist_name)
        p "------------"
        p songname
        p artist_name
        p "------------"
        if Genredata.find_by(lyricdata_id: song.id , genre: genre).nil?
            #レコードが存在しない場合の処理
            #DBに登録
            Genredata.create(lyricdata_id: targetsong.id, genre: genre)
        end    
    # end
    end
    redirect '/'
    
end

get '/songlist' do
    @songs = Lyricdata.all
    
    p "--------------"
    erb :songlist
end