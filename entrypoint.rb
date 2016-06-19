#!/usr/bin/env ruby
require_relative './src/sync_evernote'

%i[INT TERM].each { |signal| trap(signal) { STDERR.puts "\nReceived #{signal}. Exiting (0)"; exit } }

sync = SyncEvernote.new
notebooks = sync.notebooks!
saved_chunk_numbers = sync.chunks!
