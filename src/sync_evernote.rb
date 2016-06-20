require_relative './sync_serializer'
require 'set'
require 'pathname'
require 'logger'
require 'active_support'
require 'active_support/core_ext'
require 'evernote-thrift'

class SyncEvernote

  MAX_RETRIES = 5
  INTERVAL_TIME = 1.5

  def self.auth_token_from_env!
    token = ENV["EVERNOTE_DEV_TOKEN"]
    abort "Gotta set EVERNOTE_DEV_TOKEN in your env" if token.blank?
    token
  end

  def initialize(auth_token: self.class.auth_token_from_env!, dir: Pathname.new("data"), sandbox: false, logger: default_logger)
    @auth_token, @dir, @log, @sandbox = auth_token, dir, logger, sandbox
    @evernote_host = @sandbox ? "sandbox.evernote.com" : "www.evernote.com"
    @user_store_url = "https://#{@evernote_host}/edam/user"

    confirm_version!
  end

  def confirm_version!
    *version = Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
               Evernote::EDAM::UserStore::EDAM_VERSION_MINOR

    @log.info "Confirming client version... ( #{version * '.'} )"

    client_name = "Evernote EDAMTest (Ruby)"
    unless user_store.checkVersion(client_name, *version)
      message = "This client's version is too old to connect to the Evernote Cloud API! (#{version * '.'})"
      @log.fatal message
      abort message
    end
  end

  def save(resource_name, resource)
    return unless resource
    serializer(resource_name, resource).save!
    @log.info "Saved resource: #{resource_name}"
    resource
  end

  def saved_usns
    files_matching(basename: /^\d+$/).map do |f|
      File.basename(f, ".json").to_i
    end.sort!
  end

  def max_remote_usn
    count = note_store.getSyncState(@auth_token).updateCount
    @log.debug "The highest remote USN is #{count}"
    count
  end

  def max_local_usn
    last_fetched_usn = saved_usns.max
    return 1 unless last_fetched_usn
    local_resource(last_fetched_usn).chunkHighUSN
  end

  def notebooks
    thrift_attempt do
      @log.info "Fetching all notebooks"
      note_store.listNotebooks(@auth_token)
    end
  end

  def notebooks!
    save :notebooks, notebooks
  end

  def chunks!
    start_chunk_number = max_local_usn
    current_chunk = chunk! start_chunk_number
    finish_usn = max_remote_usn
    while (current_chunk.chunkHighUSN <  finish_usn) ||
          (current_chunk.chunkHighUSN < (finish_usn = max_remote_usn))
      current_chunk = chunk! current_chunk.chunkHighUSN
      yield current_chunk if block_given?
      sleep INTERVAL_TIME
    end
  end

  def chunk(chunk)
    thrift_attempt do
      @log.info "Fetching chunk: #{chunk}"
      note_store.getFilteredSyncChunk(@auth_token, chunk-1, 2147483647, sync_chunk_filter)
    end
  end

  def chunk!(chunk_number)
    save chunk_number, chunk(chunk_number)
  end

  def note(guid)
    thrift_attempt do
      @log.info "Fetching note: #{guid}"
      note_store.getNote(@auth_token, guid, true, true, true, true)
    end
  end

  def note!(guid)
    save guid, note(guid)
  end

  ##
  # Walk through every note in the SyncChunk chain, check if the local filesystem
  # version is newer than the sync chunk's note's guid. If it isn't, download it
  # and remember its ID. Every time a recently-downloaded note ID is seen again
  # it will be skipped.
  #
  def modified_notes(since_usn: 0, &block)
    return if saved_usns.none?
    fetched_note_ids = Set.new
    newer_chunks = saved_usns.select { |chunk_usn| chunk_usn > since_usn }
    enum = Enumerator.new do |yielder|
      newer_chunks.each do |chunk_number|
        notes_in_local_chunk = local_resource(chunk_number).notes || []
        notes_in_local_chunk.each do |sparse_note|
          short_id = sparse_note.guid.first 8
          next if fetched_note_ids.include?(short_id)
          if local_note_is_stale?(sparse_note.guid, sparse_note.updateSequenceNum)
            fetched_note = note sparse_note.guid
            fetched_note_ids << short_id
            yielder << fetched_note
            next
          else
            @log.debug "Local note is newer for #{short_id}"
          end
        end
      end
    end
    enum.each(&block) if block_given?
    enum
  end

  def modified_notes!(**args)
    modified_notes(**args).each do |note|
      save note.guid, note
      yield note if block_given?
      sleep INTERVAL_TIME
    end
  end

  def serializer(*args)
    SyncSerializer.new(*args, dir: @dir)
  end

  def files_matching(basename:nil, extension: ".json")
    Dir[@dir / "**/*#{extension}"].select do |filename|
      next unless filename.ends_with? extension
      base = File.basename(filename, extension)
      basename ? base =~ basename : true
    end
  end

  def local_resource(resource_name)
    serializer(resource_name).resource
  end



  private

  RATE_LIMIT_REACHED = Evernote::EDAM::Error::EDAMErrorCode::RATE_LIMIT_REACHED
  EDAMSystemException = Evernote::EDAM::Error::EDAMSystemException

  def thrift_attempt(max_retries: MAX_RETRIES)
    retries ||= max_retries.times.each # Use Enumerator to raise a StopIteration after MAX_RETRIES calls to `retries.next`
    yield
  rescue EDAMSystemException => e
    if e.errorCode == RATE_LIMIT_REACHED
      backpressure = e.rateLimitDuration
      @log.warn "RATE_LIMIT_REACHED: waking up at " +
                backpressure.seconds.from_now.strftime("%c ( %z )")
      sleep(backpressure + 0.5)
    else
      @log.warn "EDAMSystemException! #{e.inspect}"
      # abort "Got EDAMSystemException! #{e.to_json}"
    end
    retries.next && retry
  rescue Errno::ECONNRESET => e
    @log.warn "Errno::ECONNRESET! #{e.inspect}"
    retries.next && retry
  rescue SocketError => e
    @log.warn "SocketError! #{e.inspect}"
    retries.next && retry
  rescue StopIteration
    @log.error "Failed to execute Thrift operation after #{retries.count} attempts!"
    nil
  end

  def local_note_is_stale?(guid, latest_known_usn)
    local_note = local_resource guid
    local_note.nil? || latest_known_usn > local_note.updateSequenceNum
  end

  def user_store
    @user_store ||= thrift_attempt do
      http_transport = Thrift::HTTPClientTransport.new(@user_store_url)
      binary_protocol = Thrift::BinaryProtocol.new(http_transport)
      Evernote::EDAM::UserStore::UserStore::Client.new(binary_protocol)
    end
  end

  def note_store
    @note_store ||= thrift_attempt do
      http_transport = Thrift::HTTPClientTransport.new(note_store_url)
      binary_protocol = Thrift::BinaryProtocol.new(http_transport)
      Evernote::EDAM::NoteStore::NoteStore::Client.new(binary_protocol)
    end
  end

  def note_store_url
    @note_store_url ||= thrift_attempt { user_store.getNoteStoreUrl(@auth_token) }
  end

  def sleep(seconds)
    @log.debug "sleep( %.2f )" % seconds
    super
  end

  def sync_chunk_filter
    Evernote::EDAM::NoteStore::SyncChunkFilter.new \
      includeExpunged: false,
      includeNotebooks: true,
      includeLinkedNotebooks: true,
      includeTags: true,
      includeSearches: true,
      includeNotes: true,
      includeNoteResources: true,
      includeNoteAttributes: true,
      includeResources: true,
      includeNoteApplicationDataFullMap: true,
      includeResourceApplicationDataFullMap: true,
      includeNoteResourceApplicationDataFullMap: true
  end

  def default_logger
    Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG }
  end

end
