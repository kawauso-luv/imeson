require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require "net/http"
require "json"
require "nokogiri"
require 'sinatra/activerecord'
require './models'
require 'rspotify'

#EmoTune

# 歌詞検索API
def search_songs(q)
    uri = URI.parse("https://api.genius.com/search")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    uri.query = URI.encode_www_form({:q=>q})
    headers = { "Authorization" => "Bearer klsXcVPtvWvPBKszCgLJkmiYkQ4FallLavd8bh723hL-vxf8PfT-MqlJvxnlvjyG" }
    response = http.get(uri, headers)
    json = JSON.parse(response.body)
    
    
    result = []
    json["response"]["hits"].each do |song|
        next unless song["index"] == "song"
        #別アーティストの諸々を消す
        next if song["result"]["artist_names"] == "Genius Japan"
        result.push(song["result"])
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

#歌詞が日本語か判定
def is_japaanese(text) 
    "#{text}" =~ /(?:\p{Hiragana})/
end



get  '/' do
    @usertext_api=[]
    erb :index
end


post '/search' do
    $usertext = params[:usertext]
    # 感情分析API
    uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
    uri.query = URI.encode_www_form({
        :out => "json",
        :apikey => "E58B9066EE453F552DBD81B5A4D56677E3EAD7FB",
        :text => $usertext
    })
    response = Net::HTTP.get_response(uri)
    json = JSON.parse(response.body)
    @usertext_api=[]
    @usertext_api[0] = json["likedislike"]
    @usertext_api[1] = json["joysad"]
    @usertext_api[2] = json["angerfear"]
    
    puts @usertext_api
    
    
    #一番感情分析結果が近いものを見つける
    imeson = Lyricdata.all
    result = 0
    min = 9
    imeson.each do |i|
        like = i.likedislike.to_f - @usertext_api[0].to_f
        joy = i.joysad.to_f - @usertext_api[1].to_f
        ang = i.angerfear.to_f - @usertext_api[2].to_f
        result = like**2 + joy**2 + ang**2
        result = sqrt(result)
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
    ENV['ACCEPT_LANGUAGE'] = "ja"

    RSpotify.authenticate'21cd065fe0e8418dbebe103151465573','e2d37f287961402fbad6c84fcade2a63'
    
    #spotifyのプレイリストより曲データ取得
    a = RSpotify::Playlist.find_by_id('37i9dQZF1DXdbRLJPSmnyq') 
    genre = a.name
    p genre
    genre = "JPOP" if genre =~ /JPOP|J-pop/i
    genre = "JROCK" if genre =~ /JROCK|J-rock/i
    p genre
    #とりあえずの10曲プレイリスト[5TrSRWLRbWKcZyB8LgcpFr]
    
    
    a.tracks(limit: 5).each{|var|
        name = var.name()
        song = RSpotify::Track.search(name,market:'JP').first
        #曲の名前
        $songname = song.name
        p $songname
        $bpm = song.audio_features.tempo
        p $bpm
        #曲のジャンル→曲をつくったアーティストを取得→アーティストのジャンルを登録
        $artist_name = song.artists.first.name
        p $artist_name
        
        $genre = genre
        
        
        p $genre
        
        
        #歌詞検索
        songs = search_songs($songname+" "+$artist_name)
        songs.each do |s|
            $lyrics = get_lyrics(s["path"])
            if is_japaanese($lyrics)
                break
            end
        end
        
        p $artist_name
        
        #もしまだDBに登録されていなかったら
        # if Lyricdata.find_by(song: $songname, artist: $artist_name).nil?
        #     #レコードが存在しない場合の処理
            
        #     #DBに登録
        #     @uta = Lyricdata.create(song: $songname, bpm: $bpm, artist: $artist_name, genre: $genre, lyric: $lyrics)

        #     $utf8 = @uta.lyric
            
        #     #感情分析API
        #     uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
        #     uri.query = URI.encode_www_form({
        #     :out => "json",
        #     :apikey => "E58B9066EE453F552DBD81B5A4D56677E3EAD7FB",
        #     :text => $utf8
        #     })
        #     response = Net::HTTP.get_response(uri)
        #     json = JSON.parse(response.body)
        #     @songtext_api=[]
        #     @songtext_api[0] = json["likedislike"]
        #     @songtext_api[1] = json["joysad"]
        #     @songtext_api[2] = json["angerfear"]
            
        #     @uta.likedislike = @songtext_api[0]
        #     @uta.joysad = @songtext_api[1]
        #     @uta.angerfear = @songtext_api[2]
        #     @uta.save
        
        # end
        
        if Genretable.find_by(song: $songname, genre: $genre ).nil?
            #レコードが存在しない場合の処理
            
            aaa= Lyricdata.find_by(song: $songname, artist: $artist_name).id
            
            #DBに登録
            Genretable.create(song: $songname, songid: aaa, genre: $genre)
        end    

    }
    redirect '/'
    
end

get '/songlist' do
    @songs = Lyricdata.all
    erb :songlist
end