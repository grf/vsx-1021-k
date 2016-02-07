# VSX
A start at controller software for Pioneer VSX-1021k A/V receiver

It's possible to run the sinatra version one of two ways: by using a settings.yml file that contains all the necessary configuration, or by passing environment variables (useful for Docker).

## Running without Docker

### First:
```
gem install bundler --no-ri --no-rdoc
bundle install
```

### If you want to use settings.yml
```
cp settings.yml.example settings.yml
vim settings.yml # adjust for your environment
ruby ./vsx_sinatra.rb
```

### If you want to use environment variables
```
VSX_HOSTNAME=vsx.sacred.net VSX_MIN_VOLUME=-80 VSX_MAX_VOLUME=12 VSX_VOLUME_ADJUST=2 VSX_PORT=4567 ruby ./vsx_sinatra.rb
```

## Running with Docker
```
docker build --tag yourname/vsx --pull=true .
docker run --detach=true --env VSX_HOSTNAME=vsx.sacred.net --env VSX_MIN_VOLUME=-80 --env VSX_MAX_VOLUME=12 --env VSX_VOLUME_ADJUST=2 --env VSX_PORT=4567 --publish 4567:4567/tcp yourname/vsx
```

## Using Sinatra to control VSX
Turn the VSX on:
`curl localhost:4567/power/on`

Turn the VSX off:
`curl localhost:4567/power/off`

Mute toggle:
`curl localhost:4657/mute`

Mute on:
`curl localhost:4567/mute/on`

Mute off:
`curl localhost:4567/mute/off`

Increase volume:
This will increase by the amount specified in the settings.yml or the environment variable 'VSX_VOLUME_ADJUST'
`curl localhost:4567/volume/up`

Decrease volume:
This will increase by the amount specified in the settings.yml or the environment variable 'VSX_VOLUME_ADJUST'
`curl localhost:4567/volume/down`

Set volume:
Must stay within the limits set in settings.yml or the environment variables 'VSX_MIN_VOLUME' and 'VSX_MAX_VOLUME'
`curl localhost:4567/volume/-50`

Set input:
`curl localhost:4567/input/HDMI%201 # by input name`
`curl localhost:4567/PS3 # by renamed input`
`curl localhost:4567/XX # where XX is the internal ID, found by running `vsx.inputs.find_devices` in irb`

Change audio mode:
Currently limted to 'auto' and 'music' (extended stereo) but additions would be appreciated
`curl localhost:4567/listening_mode/auto`
`curl localhost:4567/listening_mode/music`

## Using scripts to control VSX
Work in Progress


## Troubleshooting
Q. Sometimes the Sinatra webapp fails to start? The error might look something like `VSX at vsx.sacred.net:4567 did not respond to status check (NoResponse)`
A. I've found my VSX can go into a deep sleep and can not be connected to. Simple re-start the application 4-5 times and it should eventually connect. It has an internal retry that tries up to 5 times before failing, so if you launch the Sinatra app 5 times it's actually tried 25 times to wake up the VSX.

Q. It's still not connecting even after launching the app many times!
A. Don't worry, I've had this happen before too. The best way to fix it is to use the Pioneer app to turn the VSX on, or with your remote, or physically pushing the power button. After it's powered on, start the Sinatra app and it will connect the first time. As long as the app is running it maintains a persistent connection with the VSX and shouldn't lose its connection unless the app is re-started.
