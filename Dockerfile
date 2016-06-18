FROM ruby
WORKDIR /mnt/sync-evernote
COPY Gemfile .
RUN bundle install
COPY . .
ENTRYPOINT $PWD/entrypoint.rb
