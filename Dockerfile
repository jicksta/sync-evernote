FROM ruby
WORKDIR /mnt/sync-evernote
COPY Gemfile .
RUN bundle install --without test
COPY . .
VOLUME /mnt/sync-evernote/data
ENTRYPOINT $PWD/entrypoint.rb
