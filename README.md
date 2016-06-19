# jicksta/sync-evernote
## For the note-taking data hackers

Given an developer Evernote Cloud API token, this Docker container will progressively and idempotently fetch the following datasets from your Evernote account:

* All un-deleted notebooks
* Full SyncChunk chain with note and tag data, sans `Note#body`
* Individual note files by GUID containing all note data, tags, and full note resources

Files are saved into the `/mnt/sync-evernote/data` volume as JSON and YAML-marshaled Thrift Ruby objects.

The worker is read-only: it never uses any write APIs.

## Getting an Evernote developer token

Visit [this page](https://sandbox.evernote.com/api/DeveloperToken.action) and grab a developer key. By default, the synchronizer does NOT use your Evernote developer sandbox account since sandbox data is rarely useful to fetch and save. You will probably have to [activate your API key](https://dev.evernote.com/support/) to grant access to your personal non-sandbox account.

## Using `jicksta/sync-evernote` with only Docker

First, you'll need to [install Docker](https://docs.docker.com/mac/step_one/) if you haven't already. If you want a quick way to run this in the cloud, use Docker Machine with one of the supported cloud providers. Or, if you don't want to install Docker at all, you can create a Docker-ready Linux machine as a DigitalOcean.com "One-click App" and run it via SSH.

From the Docker CLI tool, you can run the following command to download and run the worker.

    docker run --name sync-evernote --rm -e "EVERNOTE_DEV_TOKEN=S=s3:U=2…" -v $PWD/data:/mnt/sync-evernote/data jicksta/sync-evernote

This will auto-pull the image and write `.json` and `.yml` files into the `data` directory of your working dir.

## Using `jicksta/sync-evernote` without Docker

You just need a standard Ruby and Bundler development environment to run the synchronizer without Docker.

Basic setup for macOS:

    brew install ruby   # Optional, if you already have Ruby installed
    git clone https://github.com/jicksta/sync-evernote
    cd sync-evernote
    bundle install
    ruby entrypoint.rb

This is what the output might look like:

    $ ruby entrypoint.rb
    I, [2016-06-18T15:39:29.431344 #55451]  INFO -- : Saved resource: notebooks
    I, [2016-06-18T15:39:30.044707 #55451]  INFO -- : Number of chunks: 53343
    I, [2016-06-18T15:39:30.593545 #55451]  INFO -- : Fetching chunk: 48333
    I, [2016-06-18T15:39:32.027334 #55451]  INFO -- : Saved resource: 48333
    D, [2016-06-18T15:39:32.027380 #55451] DEBUG -- : sleep( 1.50 )
    I, [2016-06-18T15:39:33.528143 #55451]  INFO -- : Fetching chunk: 48332
    I, [2016-06-18T15:39:35.079728 #55451]  INFO -- : Saved resource: 48332
    D, [2016-06-18T15:39:35.079772 #55451] DEBUG -- : sleep( 1.50 )
    I, [2016-06-18T15:39:36.584051 #55451]  INFO -- : Fetching chunk: 48331
    I, [2016-06-18T15:39:38.038305 #55451]  INFO -- : Saved resource: 48331
    D, [2016-06-18T15:39:38.038347 #55451] DEBUG -- : sleep( 1.50 )
    I, [2016-06-18T15:39:39.541568 #55451]  INFO -- : Fetching chunk: 48330
    I, [2016-06-18T15:39:41.137313 #55451]  INFO -- : Saved resource: 48330
    D, [2016-06-18T15:39:41.137353 #55451] DEBUG -- : sleep( 1.50 )
    I, [2016-06-18T15:39:42.639847 #55451]  INFO -- : Fetching chunk: 48329
    I, [2016-06-18T15:39:44.051257 #55451]  INFO -- : Saved resource: 48329
    D, [2016-06-18T15:39:44.051320 #55451] DEBUG -- : sleep( 1.50 )
    ^C
    Received INT. Exiting (0)


## Implementation notes

This project uses the official [`evernote-thrift`](https://github.com/evernote/evernote-thrift) RubyGem.

You can view the Thrift-generated HTML API documentation [here](https://dev.evernote.com/doc/reference/).

Output files are first written to tempfiles within the container and then atomically moved into the volume when all tempfiles have been flushed and closed. This lets you rest easier killing the process.

The Thrift responses contain a lot of binary fields, mainly checksums. All binary data is automatically sanitized to url-safe Base64 in the JSON files. The marshaled Ruby Thrift objects preserve the binary objects.

The docker image has an `ENTRYPOINT`, so if you want a bash shell within the image you will have to specify `--entrypoint bash` instead of the command at the end.

## Future

Must-haves:

* Watcher mode: run in the background after full sync polling for newer chunks
* Thor-based `entrypoint.rb` for expressing subtasks

Nice-to-haves:

* Save binary Thrift files instead of YAML-marshaled Ruby objects
* Delta event stream that can replay all activity efficiently (using RethinkDB)
* Emit MQ messages with [ActiveJob](https://github.com/rails/rails/tree/master/activejob)
* Support more params as optional ENV variables
* SyncChunkFilter overrides to customize what's synced
* A separate `aws s3 sync` daemon container that links the `data` volume
