require 'curb'
require 'json'
require 'yaml'

def find_entity(nodes, attribute, name)
    nodes.each { |node|
        if node[attribute] == name then
            return node
        end
    }

    return nil
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

parameters = [
    Curl::PostField.content('grant_type', 'refresh_token'),
    Curl::PostField.content('refresh_token', config['refresh_token']),
    Curl::PostField.content('client_id', config['app_id']),
    Curl::PostField.content('client_secret', config['app_secret']),
    Curl::PostField.content('scope', 'read_station')
]

interval = config['interval']

SCHEDULER.every interval, :first_in => 0 do
    c = Curl::Easy.http_post("https://api.netatmo.net/oauth2/token", *parameters) do |curl|
        curl.headers["Content-Type"] = 'application/x-www-form-urlencoded;charset=UTF-8'
    end

    if c.response_code != 200
        puts "Netatmo Auth Response: #{c.response_code}"
    else
        json = JSON.parse(c.body_str)
        token = json['access_token']

        answer = JSON.parse(Curl.get("https://api.netatmo.net/api/getstationsdata?access_token=#{token}").body_str)

        if answer.include? 'status'
            previous_indoor_data  = indoor_data
            previous_indoor_data2  = indoor_data2
            previous_outdoor_data = outdoor_data

            station = find_entity(answer['body']['devices'], 'station_name', station_name)
            indoor_data = station['dashboard_data'] if station != nil
            
            if station != nil
                outdoor = find_entity(station['modules'], 'module_name', module_name) if station != nil
                outdoor_data = outdoor['dashboard_data'] if outdoor != nil
                indoor2 = find_entity(station['modules'], 'module_name', module2_name) if station != nil
                indoor_data2 = indoor2['dashboard_data'] if indoor2 != nil
            end

            puts "Netatmo: No indoor data" if indoor_data == nil
            puts "Netatmo: No indoor data2" if indoor_data2 == nil
            puts "Netatmo: No outdoor data" if outdoor_data == nil

            if previous_outdoor_data != nil && previous_indoor_data != nil
                send_event('netatmo_indoor',  current: indoor_data,  previous: previous_indoor_data)
                send_event('netatmo_indoor2',  current: indoor_data2,  previous: previous_indoor_data2)
                send_event('netatmo_outdoor', current: outdoor_data, previous: previous_outdoor_data)
                
		send_event('netatmo_outdoor_temperature', current: outdoor_data['Temperature'], previous: previous_outdoor_data['Temperature'])
                send_event('netatmo_outdoor_humidity', current: outdoor_data['Humidity'], previous: previous_outdoor_data['Humidity'])

                send_event('netatmo_indoor_co2',      current: indoor_data['CO2'],      previous: previous_indoor_data['CO2'])
                send_event('netatmo_indoor_noise',    current: indoor_data['Noise'],    previous: previous_indoor_data['Noise'])
                send_event('netatmo_indoor_humidity', current: indoor_data['Humidity'], previous: previous_indoor_data['Humidity'])
                send_event('netatmo_indoor_pressure', current: indoor_data['Pressure'], previous: previous_indoor_data['Pressure'])
                send_event('netatmo_indoor_temperature', current: indoor_data['Temperature'], previous: previous_indoor_data['Temperature'])
                
                send_event('netatmo_indoor2_co2',      current: indoor_data2['CO2'],      previous: previous_indoor_data2['CO2'])
                send_event('netatmo_indoor2_humidity', current: indoor_data2['Humidity'], previous: previous_indoor_data2['Humidity'])
                send_event('netatmo_indoor2_temperature', current: indoor_data2['Temperature'], previous: previous_indoor_data2['Temperature'])


                send_event('netatmo',
                  indoor:  indoor_data,
                  indoor2:  indoor_data2,
                  outdoor: outdoor_data,

                  previous_indoor: previous_indoor_data,
                  previous_indoor2: previous_indoor_data2,
                  previous_outdoor: previous_outdoor_data
                )
            end
        else
            puts "#{Time.now} Netatmo error: #{answer['error']['message']} (#{answer['error']['code']})"
        end
    end
end
