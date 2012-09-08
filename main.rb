require 'mechanize'
require 'csv'
require 'mustache'
require 'yaml'

CONFIG = YAML.load_file 'config.yml'
BASE_URL = CONFIG['base_url']
USERNAME = CONFIG['username']
PASSWORD = CONFIG['password']

a = Mechanize.new

# login
login_page = a.get "#{BASE_URL}login/"
login_page.form_with id: 'login' do |f|
    f['login[username]'] = USERNAME
    f['login[password]'] = PASSWORD
end.click_button

# get csv and put it into a useable format
csv_text = a.get("#{BASE_URL}movies/checked/?export").body
columns, *rows = CSV.parse csv_text
films = rows.map { |row| Hash[columns.zip(row)] }


# template out the result
template = File.read 'list.moustache'
rendered = Mustache.render template, films: films

# and write it to disk
File.write 'index.html', rendered