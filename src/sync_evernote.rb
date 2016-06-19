require_relative './sync_serializer'
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

  def notebooks
    note_store.listNotebooks(@auth_token)
  end

  def notebooks!
    save :notebooks, notebooks
  end

  def local_chunks
    files_matching(basename: /^\d+$/).map do |f|
      File.basename(f, ".json").to_i
    end.sort!
  end

  def max_remote_chunk
    count = note_store.getSyncState(@auth_token).updateCount
    @log.debug "The latest chunk # is #{count}"
    count
  end

  def newer_chunks
    max_local_chunk = local_chunks.max || 0
    max_remote_chunk.downto max_local_chunk.next
  end

  def older_chunks
    min_local_chunk = local_chunks.min
    return [] if min_local_chunk.nil?
    min_local_chunk.-(1).downto(1)
  end

  def needed_chunks(&block)
    enum = Enumerator.new do |yielder|
      newer_chunks.each { |n| yielder << n } until newer_chunks.none?
      older_chunks.each { |n| yielder << n }
    end
    enum.each(&block) if block_given?
    enum
  end

  def chunks!
    needed_chunks do |chunk_number|
      chunk! chunk_number
      sleep INTERVAL_TIME
    end
  end

  def chunk!(chunk_number)
    save chunk_number, chunk(chunk_number)
  end

  def chunk(chunk)
    thrift_attempt do
      @log.info "Fetching chunk: #{chunk}"
      note_store.getFilteredSyncChunk(@auth_token, chunk-1, 2147483647, sync_chunk_filter)
    end
  end

  def save(resource_name, resource)
    return unless resource
    SyncSerializer.new(resource_name.to_s, resource).save_into @dir
    @log.info "Saved resource: #{resource_name}"
    resource
  end

  private

  RATE_LIMIT_REACHED = Evernote::EDAM::Error::EDAMErrorCode::RATE_LIMIT_REACHED
  EDAMSystemException = Evernote::EDAM::Error::EDAMSystemException

  def thrift_attempt(max_retries: MAX_RETRIES)
    retries ||= max_retries.times.each # Use Enumerator to raise a StopIteration after MAX_RETRIES calls to `retries.next`
    yield
  rescue EDAMSystemException => e
    if e.errorCode == RATE_LIMIT_REACHED
      mandatory_sleep_duration = e.rateLimitDuration
      @log.warn "RATE_LIMIT_REACHED: sleeping #{mandatory_sleep_duration} seconds"
      sleep(mandatory_sleep_duration + 0.5)
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

  def files_matching(basename:nil, extension: ".json")
    Dir[@dir / "**/*#{extension}"].select do |filename|
      next unless filename.ends_with? extension
      base = File.basename(filename, extension)
      basename ? base =~ basename : true
    end
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
    @note_store_url ||= user_store.getNoteStoreUrl(@auth_token)
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
    Logger.new(STDOUT).tap { |l| l.sev_threshold = Logger::WARN }
  end

end
