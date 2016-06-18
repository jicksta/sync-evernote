#!/usr/bin/env ruby
require "pathname"
require "digest/md5"
require "evernote-thrift"
require "yaml"
require "json"
require "active_support/json"
require "logger"

log = Logger.new(STDOUT)

auth_token = ENV["EVERNOTE_DEV_TOKEN"] # https://sandbox.evernote.com/api/DeveloperToken.action

abort "Gotta set EVERNOTE_DEV_TOKEN in your env" if !auth_token || auth_token.empty?

evernote_host = "evernote.com" # "sandbox.evernote.com"
user_store_url = "https://www.#{evernote_host}/edam/user"

log.debug "Confirming client version..."

user_store_transport = Thrift::HTTPClientTransport.new(user_store_url)
user_store_protocol = Thrift::BinaryProtocol.new(user_store_transport)
user_store = Evernote::EDAM::UserStore::UserStore::Client.new(user_store_protocol)

abort "Version outdated!" unless user_store.checkVersion("Evernote EDAMTest (Ruby)",
                                                         Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                                         Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
log.info "Fetching..."

note_store_url = user_store.getNoteStoreUrl(auth_token)

note_store_transport = Thrift::HTTPClientTransport.new(note_store_url)
note_store_protocol = Thrift::BinaryProtocol.new(note_store_transport)
noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(note_store_protocol)

notebooks = noteStore.listNotebooks(auth_token)

DATA_DIR = Pathname.new("data")
NOTEBOOKS_LIST_THRIFT_FILE = DATA_DIR.join "notebooks-list.thrift.yml"
NOTEBOOKS_LIST_FILE_YML = DATA_DIR.join "notebooks-list.yml"
NOTEBOOKS_LIST_FILE_JSON = DATA_DIR.join "notebooks-list.json"

NOTEBOOKS_LIST_THRIFT_FILE.open("w+") { |f| f.write(notebooks.to_yaml) }
NOTEBOOKS_LIST_FILE_YML.open("w+") { |f| f.write(notebooks.as_json.to_yaml) }
NOTEBOOKS_LIST_FILE_JSON.open("w+") do |f|
  pretty_json = JSON.pretty_generate(notebooks.as_json)
  f.write(pretty_json)
end

log.info "Saved #{notebooks.size} notebooks"
