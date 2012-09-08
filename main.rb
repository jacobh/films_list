require 'mechanize'
require 'csv'
require 'mustache'
require 'yaml'
require 'json'
require 'nokogiri'
require 'open-uri'

CONFIG = YAML.load_file 'config.yml'
BASE_URL = CONFIG['base_url']
USERNAME = CONFIG['username']
PASSWORD = CONFIG['password']

def get_film_data(use_json=false)
    unless use_json
        a = Mechanize.new

        # login
        login_page = a.get "#{BASE_URL}login/"
        login_page.form_with id: 'login' do |f|
            f['login[username]'] = USERNAME
            f['login[password]'] = PASSWORD
        end.click_button

        # get csv and put it into a useable format
        csv_text = a.get("#{BASE_URL}movies/checked/?export").body

        # fix encoding
        csv_text = csv_text.encode 'utf-8', 'iso8859-1'

        columns, *rows = CSV.parse csv_text
        films = rows.map do |row| 
            film = Hash[columns.zip(row)]

            # clean up bool vals
            bools = ['favorite', 'disliked', 'watchlist', 'owned']
            bools.each do |bool|
                if film[bool] == "yes"
                    film[bool] = true
                else
                    film[bool] = false
                end
            end
            film['slug'] = /.*movies\/(.*)\//.match(film['url'])[1]
            film['checked'] = Date.parse(film['checked']).strftime "%d %B %Y"
            film
        end
        File.write 'output/films.json', JSON.dump(films)
        films
    else
        JSON.load File.read 'output/films.json'
    end
end

def get_covers(films)
    covers_base_url = "#{BASE_URL}var/covers/"
    cover_getters = ThreadGroup.new

    films.each do |film|
        thr = Thread.new do
            image_path = "output/covers/#{film['slug']}_small.jpg"
            unless File.exists? image_path
                print "\n\n\nNow Getting #{film['title']}\n\n\n"
                film_page = Nokogiri::HTML open film['url']
                style_dec = film_page.search('#cover .coverImage')[0].attributes['style'].content
                image_url = /url\(.*medium\/(.*)\)/.match(style_dec)[1]
                ['small', 'medium', 'large'].each do |size|
                    print "#{covers_base_url}#{size}/#{image_url}"
                    File.write(
                        "output/covers/#{film['slug']}_#{size}.jpg",
                        open("#{covers_base_url}#{size}/#{image_url}").read
                    )
                end
            end
            Thread.exit
        end
        cover_getters.add thr
        while cover_getters.list.length > 10
            print "\n\n\n\nwaiting for the queue to free up\n\n\n\n"
            sleep 3
        end

    end
    while cover_getters.list.length > 0
    end
end

films = get_film_data true
# get_covers films

# template out the result
template = File.read 'list.moustache'
rendered = Mustache.render template, films: films

# and write it to disk
File.write 'output/index.html', rendered