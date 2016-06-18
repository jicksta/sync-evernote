# jicksta/sync-evernote

Given a Evernote developer token, this Docker container will idempotently fetch
the following datasets from your Evernote account:


* All sync chunks (including notes, notebooks)
* A simple list of notebooks

Files are saved into the `data/` volume as JSON and "lossless" YAML-serialized
Thrift objects.

This system does not download note bodies, yet. Coming soon!

No data is written to your Evernote account by this synchronizer -- only reads.

## A note on performance

Unfortunately fetching all of the sync chunks can be slow, mainly due to
Evernote's rate limiting. The [`getFilteredSyncChunk`](https://dev.evernote.com/doc/reference/NoteStore.html#Fn_NoteStore_getFilteredSyncChunk) method is used to download the chunks.

I've experienced as bad as a 1500 second (25
minute) forced cooldown delay after fetching only 167 (effectively 0.3%) of my account's chunks in an 11 minute time period with 1.5s delay beteween requests. A long-term active account (e.g.
mine) can have 50,000+ chunks.

## Getting an Evernote developer token

Visit [this page](https://sandbox.evernote.com/api/DeveloperToken.action) and grab a developer key. By default, the synchronizer does NOT use your Evernote developer sandbox account since sandbox data is rarely useful to fetch and save. You will probably have to [activate your API key](https://dev.evernote.com/support/) to grant access to your personal non-sandbox account.

## Using `jicksta/sync-evernote` with only Docker

To start the synchronizer once you [install Docker](https://docs.docker.com/mac/step_one/), simply run...

```bash
EVERNOTE_DEV_TOKEN="S=s3:U=2…" docker run --name sync-evernote -d jicksta/sync-evernote -e "EVERNOTE_DEV_TOKEN=$EVERNOTE_DEV_TOKEN" -v $PWD/data:/mnt/sync-evernote/data
docker logs -f sync-evernote
```

This will auto-pull the image and write `.json` and `.yml` files into the `data` directory of
your working dir.

## Using `jicksta/sync-evernote` without Docker

You just need a standard Ruby and Bundler development environment to run
the synchronizer without Docker. On macOS, you can...

```bash
brew install ruby # Optional, if you already have Ruby installed
git clone https://github.com/jicksta/sync-evernote
cd sync-evernote
bundle install
ruby entrypoint.rb
```

This is what the output will look like:

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

## Future

Must-haves:

* Save note bodies
* Watcher mode: poll for newer chunks, fetch those first

Nice-to-haves:

* Auto-compression
* Refactor using [ActiveJob](https://github.com/rails/rails/tree/master/activejob)?
* Support more params as optional ENV variables?

