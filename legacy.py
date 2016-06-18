#!/usr/bin/env python
# Docs: https://dev.evernote.com/doc/reference/

# TODO: Figure out lossless encoding from Thrift types to JSON, OR, port this to Scala / Clojure

import string, os, base64, pyaml, yaml, sys, glob, re, time

from evernote.api.client import EvernoteClient, NoteStore
import evernote.edam.type.ttypes as Types
import evernote.edam.error.ttypes as Errors
# import evernote.edam.userstore.constants as UserStoreConstants


DEV_TOKEN = os.getenv("EVERNOTE_DEV_TOKEN")

CHUNKS_GLOB = "/chunks/*.yml"

client = EvernoteClient(token=DEV_TOKEN, sandbox=False)
noteStore = client.get_note_store()
userStore = client.get_user_store()
user = userStore.getUser()

def istext(s, threshold=0.30):
    text_characters = "".join(map(chr, range(32, 127))) + "\n\r\t\b"
    _null_trans = string.maketrans("", "")
    # if s contains any null, it's not text:
    if "\0" in s:
        return False
    # an "empty" string is "text" (arbitrary but reasonable choice):
    if not s:
        return True
    # Get the substring of s made up of non-text characters
    t = s.translate(_null_trans, text_characters)
    # s is 'text' if less than 30% of its characters are non-text ones:
    return len(t)/len(s) <= threshold



def thriftToDict(t):
    if(hasattr(t, '__dict__')):
        thriftValues = [(key, thriftToDict(value)) for (key, value) in t.__dict__.items()]
        return dict(thriftValues)
    elif(type(t) is list):
        return [thriftToDict(value) for value in t]
    elif(type(t) is str):
        return t if istext(t) else base64.b64encode(t)
    else:
        return t


def chunkForVersion(v):
    syncFilter = NoteStore.SyncChunkFilter(
        includeExpunged=False,
        includeNotebooks=True,
        includeLinkedNotebooks=True,
        includeTags=True,
        includeSearches=True,
        includeNotes=True,
        includeNoteResources=True,
        includeNoteAttributes=True,
        includeResources=True,
        includeNoteApplicationDataFullMap=True,
        includeResourceApplicationDataFullMap=True,
        includeNoteResourceApplicationDataFullMap=True
    )

    try:
        chunk = noteStore.getFilteredSyncChunk(v, 2147483647, syncFilter)
        return thriftToDict(chunk)
    except Errors.EDAMSystemException, e:
        print("here?")
        if e.errorCode == Errors.EDAMErrorCode.RATE_LIMIT_REACHED:
            print("RATE LIMIT Reached! Retrying in %d seconds" % e.rateLimitDuration)
            time.sleep(e.rateLimitDuration+1)
            return chunkForVersion(v)


def knownVersions():
    versions = []
    for file in glob.glob(CHUNKS_GLOB):
        match = re.search('\d+', file)
        if not match:
            continue
        versions.append(int(match.group(0)))
    return versions


latestVersion = noteStore.getSyncState().updateCount
# highestVersion = max(knownVersions())
highestVersion = 3553

if highestVersion is latestVersion:
    print("Already at highest version. ( %d )" % highestVersion)
    exit(0)

SLEEPY_TIME = 1.01 # seconds

def reportProgress(version, latestVersion):
    percentComplete = float(version) / latestVersion * 100
    print("%.2f%% complete\t%d / %d" % (percentComplete, version, latestVersion))


for version in range(highestVersion+1, latestVersion+1): # python's `range()` fn sucks
    reportProgress(version, latestVersion)
    chunk = chunkForVersion(version)
    chunk_filename = "/chunks/%d.yml" % version
    chunk_file = open(chunk_filename, "w+")
    yaml.safe_dump(chunk, chunk_file, allow_unicode=True, default_style='"')
    chunk_file.close()
    print("Wrote %s\t\t\tSleeping %d seconds." % (chunk_filename, SLEEPY_TIME))
    time.sleep(SLEEPY_TIME)


# Traceback (most recent call last):
#   File "synchronizer.py", line 71, in <module>
#     chunk = chunkForVersion(v)
#   File "synchronizer.py", line 66, in chunkForVersion
#     chunk = noteStore.getFilteredSyncChunk(v, 2147483647, syncFilter)
#   File "/usr/local/lib/python2.7/site-packages/evernote/api/client.py", line 138, in delegate_method
#     )(**dict(zip(arg_names, args)))
#   File "/usr/local/lib/python2.7/site-packages/evernote/edam/notestore/NoteStore.py", line 2597, in getFilteredSyncChunk
#     return self.recv_getFilteredSyncChunk()
#   File "/usr/local/lib/python2.7/site-packages/evernote/edam/notestore/NoteStore.py", line 2625, in recv_getFilteredSyncChunk
#     raise result.systemException
# evernote.edam.error.ttypes.EDAMSystemException: EDAMSystemException(errorCode=19, rateLimitDuration=3256, _message=None)
