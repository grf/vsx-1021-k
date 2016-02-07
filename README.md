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

### Running with Docker
```
docker build --tag yourname/vsx --pull=true .
docker run --detach=true --env VSX_HOSTNAME=vsx.sacred.net --env VSX_MIN_VOLUME=-80 --env VSX_MAX_VOLUME=12 --env VSX_VOLUME_ADJUST=2 --env VSX_PORT=8091 --publish 8091:8091/tcp yourname/vsx
```
