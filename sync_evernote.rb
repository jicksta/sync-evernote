# require "digest/md5"
require 'pathname'
require 'evernote-thrift'
require 'active_support'
require 'active_support/core_ext'
require 'logger'

class SyncEvernote

  MAX_RETRIES = 5
  INTERVAL_TIME = 1.5

  def initialize(auth_token, dir: Pathname.new("data"), sandbox: true, logger: Logger.new(STDOUT))
    @auth_token, @dir, @log, @sandbox = auth_token, dir, logger, sandbox
    @evernote_host = @sandbox ? "sandbox.evernote.com" : "www.evernote.com"
    @user_store_url = "https://#{@evernote_host}/edam/user"
  end

  def confirm!
    version = [
      Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
      Evernote::EDAM::UserStore::EDAM_VERSION_MINOR
    ]
    client_name = "Evernote EDAMTest (Ruby)"

    @log.debug "Confirming client version... ( #{version.join('.')} )"
    abort "Version outdated!" unless user_store.checkVersion(client_name, *version)
  end

  def notebooks
    note_store.listNotebooks(@auth_token)
  end

  def notebooks!
    save :notebooks, notebooks
  end

  def local_chunks
    files_matching(basename: /^\d+$/).map { |f| File.basename(f, ".json").to_i }.sort
  end

  def max_remote_chunk
    note_store.getSyncState(@auth_token).updateCount
  end

  def needed_chunks(&block)
    local = local_chunks
    newer = max_remote_chunk...local.max
    older = local.min.-(1).downto(1)
    enum = Enumerator.new do |yielder|
      newer.each { |n| yielder << n }
      older.each { |n| yielder << n }
    end
    enum.each(&block) if block_given?
    enum
  end

  def chunks!
    needed_chunks do |chunk_number|
      chunk = fetch_chunk_by_number chunk_number
      next if chunk.nil?
      save chunk_number, chunk
      sleep INTERVAL_TIME
    end
  end

  private

  RATE_LIMIT_REACHED = Evernote::EDAM::Error::EDAMErrorCode::RATE_LIMIT_REACHED
  EDAMSystemException = Evernote::EDAM::Error::EDAMSystemException

  def save(resource_name, resource)
    SyncSerializer.new(resource_name.to_s, resource).save_into @dir
    @log.info "Saved resource: #{resource_name}"
    resource
  end

  def files_matching(basename:nil, extension: ".json")
    Dir[@dir / "**/*#{extension}"].select do |filename|
      next unless filename.ends_with? extension
      base = File.basename(filename, extension)
      basename ? base =~ basename : true
    end
  end

  def user_store
    @user_store ||= begin
      http_transport = Thrift::HTTPClientTransport.new(@user_store_url)
      binary_protocol = Thrift::BinaryProtocol.new(http_transport)
      Evernote::EDAM::UserStore::UserStore::Client.new(binary_protocol)
    end
  end

  def note_store
    @note_store ||= begin
      http_transport = Thrift::HTTPClientTransport.new(note_store_url)
      binary_protocol = Thrift::BinaryProtocol.new(http_transport)
      Evernote::EDAM::NoteStore::NoteStore::Client.new(binary_protocol)
    end
  end

  def note_store_url
    @note_store_url ||= user_store.getNoteStoreUrl(@auth_token)
  end

  def fetch_chunk_by_number(chunk)
    retries ||= 5.times.each
    @log.info "Fetching chunk #{chunk}"
    note_store.getFilteredSyncChunk(@auth_token, chunk-1, 2147483647, sync_chunk_filter)
  rescue EDAMSystemException => e
    if e.errorCode == RATE_LIMIT_REACHED
      mandatory_sleep_duration = e.rateLimitDuration
      @log.warn "RATE_LIMIT_REACHED for chunk ##{chunk}: #{mandatory_sleep_duration} seconds"
      sleep(mandatory_sleep_duration + 0.5)
    end
    retries.next && retry
  rescue Errno::ECONNRESET
    retries.next && retry
  rescue StopIteration
    @log.error "Failed to fetch chunk #{chunk} after #{retries.count} attempts"
    nil
  end

  def sleep(seconds)
    @log.debug "sleep(%.2f)" % seconds
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

end
