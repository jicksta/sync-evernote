# jicksta/sync-evernote

Given a Evernote developer token, this Docker container will idempotently fetch
the following datasets from your Evernote account:


* All sync chunks (including notes, notebooks)
* A simple list of notebooks

Files are saved into the `data/` volume as JSON and "lossless" YAML-serialized
Thrift objects.

This system does not download note bodies, yet. Coming soon!

## A note on performance

Unfortunately fetching all of the sync chunks can be slow, mainly due to
Evernote's rate limiting. The [`getFilteredSyncChunk`](https://dev.evernote.com/doc/reference/NoteStore.html#Fn_NoteStore_getFilteredSyncChunk) method is used to download the chunks.

I've experienced as bad as a 1500 second (25
minute) forced cooldown delay after fetching only 167 (effectively 0.3%) of my account's chunks in an 11 minute time period. A long-term active account (e.g.
mine) can have 50,000+ chunks.

## Getting an Evernote developer token

Visit [this page](https://sandbox.evernote.com/api/DeveloperToken.action) and grab a production key. By default, the synchronizer does NOT use your Evernote developer sandbox account since sandbox data is rarely useful to fetch and save.

You may have to submit a ticket to their developer support folks to get your
account flagged for permission to access non-sandbox data.

## Using `jicksta/sync-evernote` with only Docker

To start the synchronizer once you [install Docker](https://docs.docker.com/mac/step_one/), simple run...

```bash
EVERNOTE_DEV_TOKEN="S=s3:U=2…" docker run --name sync-evernote -d jicksta/sync-evernote -e "EVERNOTE_DEV_TOKEN=$EVERNOTE_DEV_TOKEN" -v $PWD/data:/mnt/sync-evernote/data
docker logs -f sync-evernote
```

This will write `.json` and `.yml` files into the `data` directory of
your.

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

## Implementation notes

This project uses the official [`evernote-thrift`](https://github.com/evernote/evernote-thrift) RubyGem.

You can view the Thrift-generated HTML API documentation [here](https://dev.evernote.com/doc/reference/).
