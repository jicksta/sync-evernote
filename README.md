# jicksta/sync-evernote
## For the note-taking data hackers

Given a Evernote developer token, this Docker container will progressively and idempotently fetch the following datasets from your Evernote account:

* All sync chunks (including notes, notebooks)
* A simple list of notebooks

Files are saved into the `/mnt/sync-evernote/data` volume as JSON and YAML-marshaled Thrift Ruby objects.

*This system does not download note bodies, yet. Coming soon!*

This code does not use any write APIs; it only ever reads.

## A note on performance

Unfortunately fetching all of the sync chunks can be slow, mainly due to Evernote's rate limiting. The [`getFilteredSyncChunk`](https://dev.evernote.com/doc/reference/NoteStore.html#Fn_NoteStore_getFilteredSyncChunk) method is used to download the chunks.

I've experienced as bad as a 1500 second (25 minute) forced cool-down delay after fetching only 167 (effectively 0.3%) of my account's chunks in an 11 minute time period with 1.5s delay between requests. A long-term active account (e.g. mine) can have 50,000+ chunks.

## Getting an Evernote developer token

Visit [this page](https://sandbox.evernote.com/api/DeveloperToken.action) and grab a developer key. By default, the synchronizer does NOT use your Evernote developer sandbox account since sandbox data is rarely useful to fetch and save. You will probably have to [activate your API key](https://dev.evernote.com/support/) to grant access to your personal non-sandbox account.

## Using `jicksta/sync-evernote` with only Docker

First, you'll need to [install Docker](https://docs.docker.com/mac/step_one/) if you haven't already. Alternatively, if you wanted to run this on a paid cloud hosting provider, you could use DigitalOcean's "One-click-App" for a Docker-configured Linux machine and have this running with `docker -d` in the background in the cloud.

From the Docker CLI tool, you can run the following command to download and run the worker.

    docker run --name sync-evernote --rm jicksta/sync-evernote -e "EVERNOTE_DEV_TOKEN=S=s3:U=2…" -v $PWD/data:/mnt/sync-evernote/data

This will auto-pull the image and write `.json` and `.yml` files into the `data` directory of your working dir.

## Using `jicksta/sync-evernote` without Docker

You just need a standard Ruby and Bundler development environment to run the synchronizer without Docker. On macOS, you can...

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

* Save note bodies
* Save attachments' data, OCR data
* Watcher mode: run in the background after full sync polling for newer chunks
* Auto-detect missing chunks that are missing in the volume

Nice-to-haves:

* Delta event stream that can replay all activity efficiently (using RethinkDB)
* Support saving to columnar, compressed file format (Parquet with JRuby)
* Emit MQ messages with [ActiveJob](https://github.com/rails/rails/tree/master/activejob)
* Support more params as optional ENV variables
* Prioritize or exclude notebooks from sync
* A separate `aws s3 sync` daemon container that links the `data` volume
