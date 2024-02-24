class GeniusApi
    class << self
        def search_songs(q)
            uri = URI.parse("https://api.genius.com/search")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme === "https"
            uri.query = URI.encode_www_form({:q=>q})
            headers = { "Authorization" => "Bearer #{ENV["LYRIC_API"]}" }
            response = http.get(uri, headers)
            json = JSON.parse(response.body)
            
            result = []
            json["response"]["hits"].each do |song|
                next unless song["index"] == "song"
                #別アーティストの諸々を消す
                next if song["result"]["artist_names"] == "Genius Japan"
                result.push(song["result"]["id"])
            end
            
            result
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
            
            if div.empty?
                return nil # 歌詞が見つからない場合はnilを返す
            end
            
            div.search(:b).map &:remove
            div.inner_text.gsub(/\[.*?\]/,"")
        end
        
        
        
        
        
        
        # def content_lyrics(q)   
        #     div = q.css(".Lyrics__Container-sc-1ynbvzw-1.kUgSbL")
            
        #     if div.empty?
        #         return nil # 歌詞が見つからない場合はnilを返す
        #     end
            
        #     div.search(:b).map &:remove
        #     div.inner_text.gsub(/\[.*?\]/,"")
            
        #     return div
        # end
        
        # def content_title(q, name)   
        #     title = q.css(".SongHeaderdesktop__HiddenMask-sc-1effuo1-11.iMpFIj")
            
        #     titletf = title.include?(name)
            
        #     if title.empty?
        #         return nil
        #     end
            
        #     return titletf
        # end
        
        
    end 
end