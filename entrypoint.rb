#!/usr/bin/env ruby
require_relative './src/sync_evernote'

%i[INT TERM].each { |signal| trap(signal) { STDERR.puts "\nReceived #{signal}. Exiting (0)"; exit } }

logger = Logger.new(STDOUT)

sync = SyncEvernote.new(logger: logger)
notebooks = sync.notebooks!
saved_chunk_numbers = sync.chunks!
