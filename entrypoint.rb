#!/usr/bin/env ruby
require_relative './src/sync_evernote'
require_relative './src/sync_serializer'

AUTH_TOKEN = ENV["EVERNOTE_DEV_TOKEN"] # https://sandbox.evernote.com/api/DeveloperToken.action
abort "Gotta set EVERNOTE_DEV_TOKEN in your env" if AUTH_TOKEN.blank?

%i[INT TERM].each { |signal| trap(signal) { STDERR.puts "\nReceived #{signal}. Exiting (0)"; exit } }

logger = Logger.new(STDOUT)

sync = SyncEvernote.new(AUTH_TOKEN, sandbox: false, logger: logger)

notebooks = sync.notebooks!
logger.info "Number of chunks: #{sync.max_remote_chunk}"

saved_chunk_numbers = sync.chunks!
logger.info "Saved #{saved_chunk_numbers.count} chunks!"
