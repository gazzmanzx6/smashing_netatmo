require 'sinatra'
require 'net/http'
require 'json'
require 'uri'
require 'yaml'

class MyApp < Sinatra::Base

config = YAML.load_file("config/netatmo.yml")
ID = config['client_id']
SECRET = config['client_secret']
REDIRECT_URI = 'http://localhost:4567/callback'

get '/' do
  '<a href="/authorize">Connect to Netatmo</a>'
end

get '/authorize' do
  redirect to("https://api.netatmo.com/oauth2/authorize?client_id=#{ID}&redirect_uri=#{REDIRECT_URI}&scope=read_station&response_type=code")
end

get '/callback' do
  authorization_code = params[:code]

  uri = URI('https://api.netatmo.com/oauth2/token')
  response = Net::HTTP.post_form(uri, {
    'grant_type' => 'authorization_code',
    'client_id' => ID,
    'client_secret' => SECRET,
    'code' => authorization_code,
    'redirect_uri' => REDIRECT_URI
  })

  token_data = JSON.parse(response.body)
  access_token = token_data['access_token']
  refresh_token = token_data['refresh_token']
  expires_in = token_data['expires_in']
  expires_at = Time.now.to_i + expires_in

  # Store tokens in a file or a database
  File.open('tokens.json', 'w') do |f|
    f.write(JSON.pretty_generate({ access_token: access_token, refresh_token: refresh_token, expires_at: expires_at }))
  end

  redirect to('/dashboard')
end

get '/dashboard' do
  # Read access token from file
  tokens = JSON.parse(File.read('tokens.json'))
  access_token = tokens['access_token']

  uri = URI("https://api.netatmo.com/api/getstationsdata?access_token=#{access_token}")
  response = Net::HTTP.get(uri)
  data = JSON.parse(response)

  # Extract and display the required data
  if data['body'] && data['body']['devices'] && data['body']['devices'][0]
    temperature = data['body']['devices'][0]['dashboard_data']['Temperature']
    humidity = data['body']['devices'][0]['dashboard_data']['Humidity']

    "Temperature: #{temperature}°C, Humidity: #{humidity}%"
  else
    "Error: Unable to fetch data from Netatmo API"
  end
end

run! if app_file == $0
end
