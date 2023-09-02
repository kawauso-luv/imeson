require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require "net/http"
require "json"
require "nokogiri"
require 'sinatra/activerecord'
require './models'
require 'rspotify'


# 歌詞検索API
def search_songs(q)
    uri = URI.parse("https://api.genius.com/search")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    uri.query = URI.encode_www_form({:q=>q})
    
    # AIMgwM4W92uWzT1HrUhKi_hb7jUDCiNnnslsDivN3NG3SwXqJA0zj0kaJnsAlAGa
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
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme === "https"
    response = http.get(uri)

    doc = Nokogiri::HTML(response.body)
    
    div = doc.css("#lyrics-root > .Lyrics__Container-sc-1ynbvzw-5.Dzxov")
    # p "div: #{div}"
    
    div.search(:b).map &:remove
    div.inner_text.gsub(/\[.*?\]/,"")
    
end

#歌詞が日本語か判定
def is_japaanese(text) 
    "#{text}" =~ /(?:\p{Hiragana})/
end

# songs = search_songs("米津 Lemon")
# songs.each do |s|
#     $lyrics = get_lyrics(s["path"])
#     if is_japaanese($lyrics)
#         puts $lyrics
#     end
#     sleep 1
# end

# a="hellllo"
# puts a
# puts $lyrics




#歌詞品詞分解（mecab&natto）
# nm = Natto::MeCab.new

# text = '太郎はこの本を二郎を見た女性に渡した。'
# nm.parse(text) do |n|
#   puts " >> #{n.surface} \t>> #{n.feature}"
# end

# @aaa = Lyricdata.find(1)
#     p @aaa


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
    
    
    imeson = Lyricdata.all
    result = 0
    min = 3
    imeson.each do |i|
        like = i.likedislike - @usertext_api[0].to_f
        joy = i.joysad - @usertext_api[1].to_f
        ang = i.angerfear - @usertext_api[2].to_f
        result = like+joy+ang
        result = result.abs
        if min>result
            min = result.abs
            @song = i.song
            @lyric = i.lyric
        end
    end
    
    
    
    erb :index
end

get '/search' do
    erb :index
end




get  '/song' do
    @songtext_api=[]
    erb :load
end

post '/load' do
    $songtext = params[:songtext]
    # 感情分析API
    uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
    uri.query = URI.encode_www_form({
        :out => "json",
        :apikey => "E58B9066EE453F552DBD81B5A4D56677E3EAD7FB",
        :text => $songtext
    })
    response = Net::HTTP.get_response(uri)
    json = JSON.parse(response.body)
    @songtext_api=[]
    @songtext_api[0] = json["likedislike"]
    @songtext_api[1] = json["joysad"]
    @songtext_api[2] = json["angerfear"]
    
    @kasi = Lyricdata.create(song: params[:songname], lyric: params[:songtext], likedislike: @songtext_api[0], joysad: @songtext_api[1], angerfear: @songtext_api[2])
    puts @songtext_api
    puts @kasi.song
    
    erb :load
end

get '/load' do
    erb :load
end

get '/test' do
    ENV['ACCEPT_LANGUAGE'] = "ja"

    RSpotify.authenticate'21cd065fe0e8418dbebe103151465573','e2d37f287961402fbad6c84fcade2a63'

    #まずいろんな曲をDBに入れるぜ
    
    #ジャンルごとに検索する　作り途中
    # search = RSpotify::Recommendations.generate(seed_genres: ['j-pop'],market:'JP',seed_artists:[''])
    # search.tracks.map {|track| [track.artists.first.name, track.name].join('/')}
    
    a = RSpotify::Playlist.find_by_id('5rzPmrC1h6iax9GtzvCKBi')
    a.tracks(limit:1).each{|var|
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
        genre_tmp = RSpotify::Artist.search($artist_name).first
        $genre = genre_tmp.genres
        p $genre
        
        songs = search_songs($songname+" "+$artist_name)
        songs.each do |s|
            $lyrics = get_lyrics(s["path"])
            if is_japaanese($lyrics)
                puts "lyrics: #{$lyrics}"
                break
            end
            sleep 1
        end
        
        #もしまだDBに登録されていなかったら
        # if Lyricdata.find_by(song: $songname, artist: $artist_name).nil?
            # レコードが存在しない場合の処理
            utf8 = $lyrics.force_encoding(Encoding::SJIS)
            
            #感情分析API
            uri = URI("http://ap.mextractr.net/ma9/emotion_analyzer")
            uri.query = URI.encode_www_form({
            :out => "json",
            :apikey => "E58B9066EE453F552DBD81B5A4D56677E3EAD7FB",
            :text => utf8
            })
            response = Net::HTTP.get_response(uri)
            json = JSON.parse(response.body)
            
            p "res: #{json.to_json}"
            
            
            # @kanzyou_api = Faraday.new(:url => "http://ap.mextractr.net/ma9/")
            # res = @kanzyou_api.get 'emotion_analyzeremotion_analyzer?out=json&apikey=E58B9066EE453F552DBD81B5A4D56677E3EAD7FB&text=%E3%81%82%E3%82%8A%E3%81%8C%E3%81%A8%E3%81%86%EF%BC%81%E3%81%82%E3%82%8A%E3%81%8C%E3%81%A8%E3%81%86%EF%BC%81%E3%81%86%E3%82%8C%E3%81%97%E3%81%84%EF%BC%81%EF%BC%81%EF%BC%81%EF%BC%81'
            # body = JSON.parse(res.body)
            
            # p "body: #{body}"
            
            
            # Nokogiriを使用してXMLをパース
            # doc = Nokogiri::XML(response.body)

            # # パースしたXMLをハッシュに変換
            # xml_hash = {}
            
            # p "doc: #{doc}"
            # doc.root.elements.each do |element|
            #   xml_hash[element.name] = element.text
            # end
            
            # # ハッシュをJSONに変換
            # json_response = JSON.generate(xml_hash)
            
            # # JSONレスポンスを出力
            # puts json_response
            
            
            # @songtext_api=[]
            # @songtext_api[0] = json["likedislike"]
            # @songtext_api[1] = json["joysad"]
            # @songtext_api[2] = json["angerfear"]
    
            # @uta = Lyricdata.create(song: $songname, bpm: $bpm, artist: $artist_name, genre: $genre, lyric: $lyrics, likedislike: @songtext_api[0], joysad: @songtext_api[1], angerfear: @songtext_api[2])
            # p @uta
        # else
            # p Lyricdata.find_by(song: $songname,artist: $artist_name)
        # end
    }
    
=begin
    # 曲名を検索し、一番上に出てきたものを取得する。
    song = RSpotify::Track.search('馬と鹿').first
    #曲の名前
    p song.name
    #曲のジャンル→曲をつくったアーティストを取得→アーティストのジャンルを登録
    artist_name = song.artists.first.name
    genre_tmp = RSpotify::Artist.search(artist_name).first
    genre = genre_tmp.genres
    p genre
    
    #BPM→曲のidを取得→Audio Featuresのtempo
    bpm = song.audio_features.tempo
    p bpm
    #or
    songid = song.id
    tempo = RSpotify::AudioFeatures.find(songid)

    # #作者→曲を作ったアーティストを取得
    p artist_name
    
    # energy numberが高めのJ-POPに絞って検索しています。
    #recommendations = RSpotify::Recommendations.generate(seed_genres: ['j-pop'], target_energy:0.8 )

    #p recommendations.tracks.map {|track| [track.artists.first.name, track.name].join('/')}

=end

    erb :test
end