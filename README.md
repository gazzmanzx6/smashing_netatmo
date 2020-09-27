Description
===========

A [Smashing](https://github.com/Smashing/smashing) widget to display readings from your [Netatmo](https://www.netatmo.com) Personal Weather Station (PWS).

Dependencies
============

You need an account and Weather Station from [Netatmo](https://www.netatmo.com).

You also need to register an own app at [Netatmo Developer](https://dev.netatmo.com) to get access to all readings from your PWS.

Add to dashing's gemfile:
```
gem 'curb'
gem 'json'
```
and run `bundle install`.

Usage
============

Update your settings in config/netatmo.yml

Add the widget HTML to your dashboard
```
    <li data-row="1" data-col="5" data-sizex="1" data-sizey="5">
      <div data-id="netatmo" data-view="Netatmo"></div>
    </li>
```
