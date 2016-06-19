#!/usr/bin/env ruby
%i[INT TERM].each { |signal| trap(signal) { STDERR.puts "\nReceived #{signal}. Exiting (0)"; exit } }
require_relative './src/sync_evernote'

logger = Logger.new(STDOUT)
sync   = SyncEvernote.new(logger: logger)

sync.notebooks!
sync.chunks!
sync.modified_notes!
