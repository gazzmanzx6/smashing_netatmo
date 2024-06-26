Description
===========

A [Smashing](https://github.com/Smashing/smashing) widget to display readings from your [Netatmo](https://www.netatmo.com) Personal Weather Station (PWS).

Dependencies
============

You need an account and Weather Station from [Netatmo](https://www.netatmo.com).

You also need to register your own app at [Netatmo Developer](https://dev.netatmo.com) to get access to all readings from your PWS.
Once the app is created you need to generate a refresh_token as username and password are no longer accepted by the Netatmo API.

Add to dashing's gemfile:
```
gem 'curb'
gem 'json'
gem 'sinatra'
gem 'thin'
gem 'net-http'
gem 'oauth2'
```
and run `bundle install`.

Usage
============

Update your settings in config/netatmo.yml

Copy the app.rb file to the smashing-dashboards/dashboard folder and run it using:
```
ruby app.rb -o 0.0.0.0
```
Then in the browser navigate to http://localhost:4567
Click on the link to authenticate via the Netatmo site.

This will save the access & refresh tokens in the tokens.json file.

Add the widget HTML to your dashboard
```
    <li data-row="1" data-col="5" data-sizex="1" data-sizey="5">
      <div data-id="netatmo" data-view="Netatmo"></div>
    </li>
```
