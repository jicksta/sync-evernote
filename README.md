# jicksta/sync-evernote

Given a Evernote developer token, this Docker container will idempotently fetch
the following datasets:


* All sync chunks (including notes, notebooks)
* A simple list of notebooks

Files are saved into the `data/` volume as JSON and "lossless" serialized
Thrift structs.

Note: Unfortunately fetching all of the sync chunks can be slow, mainly due to
Evernote's rate limiting. [`getFilteredSyncChunk`](https://dev.evernote.com/doc/reference/NoteStore.html#Fn_NoteStore_getFilteredSyncChunk)
is used to download the chunks.

Unfortunately this system does not download note bodies, YET!

## Using `jicksta/sync-evernote` with only Docker

docker run --rm evernote

Install Ruby to run `rake` if you don't have it already.

    git clone https://github.com/jicksta/sync-evernote
    cd sync-evernote
    EVERNOTE_DEV_TOKEN="S=s3:U=2…" rake start


You don't need to `bundle install` or do anything
