require 'curb'
require 'json'
require 'yaml'
require 'oauth2'
require 'time'

def find_entity(nodes, attribute, name)
  nodes.each { |node|
    return node if node[attribute] == name
  }
  nil
end

def refresh_access_token(client, refresh_token)
  puts "Refreshing access token..."
  begin
    token = OAuth2::AccessToken.new(client, '', refresh_token: refresh_token)
    new_token = token.refresh!
    expires_at = Time.now.to_i + new_token.expires_in
    puts "New access token: #{new_token.token}"
    puts "New refresh token: #{new_token.refresh_token}"
    puts "Token expires at: #{Time.at(expires_at)}"
    new_token_info = {
      'access_token' => new_token.token,
      'refresh_token' => new_token.refresh_token,
      'expires_at' => expires_at
    }
  # Store tokens in a file or a database
  File.open('tokens.json', 'w') do |f|
    f.write(JSON.pretty_generate( new_token_info ))
  end
    #File.write('/home/pi/smashing-dashboards/dashboard/tokens.json', new_token_info.to_json)
    new_token_info
  rescue OAuth2::Error => e
    puts "Failed to refresh token: #{e.message}"
    nil
  end
end

def token_expired?(expires_at)
  Time.now.to_i >= expires_at
end

indoor_data = nil
indoor_data2 = nil
outdoor_data = nil

previous_indoor_data = nil
previous_indoor_data2 = nil
previous_outdoor_data = nil

config = YAML.load_file("config/netatmo.yml")

# -- maintain compatibility with older version:
station_name = config['station_name'] ? config['station_name'] : config['indoor_name']
module2_name = config['module2_name'] ? config['module2_name'] : config['indoor2_name']
module_name  = config['module_name']  ? config['module_name']  : config['outdoor_name']
# --

interval = config['interval']

# OAuth2 Client Setup
client = OAuth2::Client.new(
  config['client_id'],
  config['client_secret'],
  site: 'https://api.netatmo.com',
  token_url: '/oauth2/token'
)

SCHEDULER.every interval, first_in: 0 do

  tokens = JSON.parse(File.read('tokens.json'))
  access_token = tokens['access_token']
  refresh_token = tokens['refresh_token']
  expires_at = tokens['expires_at']

  puts "Current access token: #{access_token}"
  puts "Current refresh token: #{refresh_token}"
  puts "Token expires at: #{Time.at(expires_at)}"

  if token_expired?(expires_at)
    puts "Token expired. Attempting to refresh..."
    new_token_info = refresh_access_token(client, refresh_token)
    if new_token_info.nil?
      puts "Failed to refresh token. Exiting..."
      next
    end
    access_token = new_token_info['access_token']
    expires_at = new_token_info['expires_at']
  end

  url = "https://api.netatmo.com/api/getstationsdata?access_token=#{access_token}"

  response = Curl.get(url)
  response_code = response.response_code
  response_body = response.body_str

  if response_code == 200
    answer = JSON.parse(response_body)
    if answer.include?('status')
      previous_indoor_data = indoor_data
      previous_indoor_data2 = indoor_data2
      previous_outdoor_data = outdoor_data

      station = find_entity(answer['body']['devices'], 'station_name', station_name)
      indoor_data = station['dashboard_data'] if station

      if station
        outdoor = find_entity(station['modules'], 'module_name', module_name)
        outdoor_data = outdoor['dashboard_data'] if outdoor
        indoor2 = find_entity(station['modules'], 'module_name', module2_name)
        indoor_data2 = indoor2['dashboard_data'] if indoor2
      end

      puts "Netatmo: No indoor data" if indoor_data.nil?
      puts "Netatmo: No indoor data2" if indoor_data2.nil?
      puts "Netatmo: No outdoor data" if outdoor_data.nil?

      if previous_outdoor_data && previous_indoor_data
        send_event('netatmo_indoor', current: indoor_data, previous: previous_indoor_data)
        send_event('netatmo_indoor2', current: indoor_data2, previous: previous_indoor_data2)
        send_event('netatmo_outdoor', current: outdoor_data, previous: previous_outdoor_data)

        send_event('netatmo_outdoor_temperature', current: outdoor_data['Temperature'], previous: previous_outdoor_data['Temperature'])
        send_event('netatmo_outdoor_humidity', current: outdoor_data['Humidity'], previous: previous_outdoor_data['Humidity'])

        send_event('netatmo_indoor_co2', current: indoor_data['CO2'], previous: previous_indoor_data['CO2'])
        send_event('netatmo_indoor_noise', current: indoor_data['Noise'], previous: previous_indoor_data['Noise'])
        send_event('netatmo_indoor_humidity', current: indoor_data['Humidity'], previous: previous_indoor_data['Humidity'])
        send_event('netatmo_indoor_pressure', current: indoor_data['Pressure'], previous: previous_indoor_data['Pressure'])
        send_event('netatmo_indoor_temperature', current: indoor_data['Temperature'], previous: previous_indoor_data['Temperature'])

        send_event('netatmo_indoor2_co2', current: indoor_data2['CO2'], previous: previous_indoor_data2['CO2'])
        send_event('netatmo_indoor2_humidity', current: indoor_data2['Humidity'], previous: previous_indoor_data2['Humidity'])
        send_event('netatmo_indoor2_temperature', current: indoor_data2['Temperature'], previous: previous_indoor_data2['Temperature'])

        send_event('netatmo',
                   indoor: indoor_data,
                   indoor2: indoor_data2,
                   outdoor: outdoor_data,
                   previous_indoor: previous_indoor_data,
                   previous_indoor2: previous_indoor_data2,
                   previous_outdoor: previous_outdoor_data)
      end
    else
      puts "#{Time.now} Netatmo error: #{answer['error']['message']} (#{answer['error']['code']})"
    end
  else
    puts "Failed to get data from Netatmo. HTTP status code: #{response_code}"
  end
end
