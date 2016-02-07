FROM ruby:2.3-alpine

COPY Gemfile* /
COPY vsx_sinatra.rb /
COPY lib/* /lib/

RUN apk update && apk upgrade && apk add libstdc++ && apk --update add --virtual build_deps ruby-dev build-base && bundle install && apk del build_deps

CMD ["ruby", "/vsx_sinatra.rb"]
