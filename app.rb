require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require "net/http"
require "json"
require "nokogiri"
require 'sinatra/activerecord'
require './models'
require 'rspotify'
require "./lib/genius_api.rb"
require "./lib/emotionanalyzer_api.rb"

Dotenv.load

#EmoTune


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
    selected_genre = params[:genre]
    # 感情分析API
    data = EmotionanalyzerApi.analyze(usertext, selected_genre)
    
    @usertext_api = data[:usertext_api]
    @artist = data[:artist]
    @song = data[:song]
    @lyric = data[:lyric]
    
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
    a = RSpotify::Playlist.find_by_id('2CmfNZ3ZBXrB9vdLcZUcqX') 
    genre = a.name
    p genre
    genre = "JPOP" if genre =~ /JPOP|J-pop|J-POP/i
    genre = "JROCK" if genre =~ /JROCK|J-rock|J-ROCK/i
    p genre
    #とりあえずの10曲プレイリスト[5TrSRWLRbWKcZyB8LgcpFr]

    a.tracks(limit:5).each do |var|
    #いったんfor文作る前に戻した大丈夫なはず
    #tracks = a.tracks(limit: 5)
    #for song in tracks
        id = var.id
        song = RSpotify::Track.find(id)
        songname = song.name
        bpm = song.audio_features.tempo
        #曲のジャンル→曲をつくったアーティストを取得→アーティストのジャンルを登録
        artist_name = song.artists.first.name
        
        
        #spotifyのパラメータたち
        #ダンスしやすさ +:1.0, -:0.0
        danceability = song.audio_features.danceability
        #エネルギー +:1.0, -:0.0
        energy = song.audio_features.energy
        #曲が伝える音楽のポジティブ性を表す0.0から1.0の尺度。この指数の高い値の曲はより陽性,低い指数の曲はより陰性
        valence = song.audio_features.valence
        
        genre = genre
        
        
        
        #歌詞検索
        # content = GeniusApi.search_songs(songname+" "+artist_name)
        # p content
        # title = GeniusApi.content_title(content, songname)
        # p title.to_s
        # if title==true
        #     songs = GeniusApi.content_lyrics(content)
        # end
        songs = GeniusApi.search_songs(songname+" "+artist_name)
        
        songs.each do |s|
        if s.nil?
            $lyrics = nil
            next
        else
            #$lyrics = get_lyrics(s["path"])
            $lyrics = GeniusApi.get_content(s)
            puts "~~~~#{$lyrics}~~~~~~~~~"
            
            if is_japaanese($lyrics)
                # @jap = true
                break
            else
                $lyrics = nil
                next
            end
        end
        end
        
        
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
            p response.body
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
    end
    redirect '/'
    
end

get '/songlist' do
    @songs = Lyricdata.all
    
    p "--------------"
    erb :songlist
end