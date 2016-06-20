require "tempfile"
require "fileutils"
require "base64"
require "yaml"
require "active_support/json"

class SyncSerializer

  def self.sanitize(t_value)
    value = t_value.as_json
    case value
      when Hash
        value.each.with_object({}) { |(k, v), memo| memo[k] = sanitize(v) }
      when Array
        value.map { |x| sanitize(x) }
      when String
        (value.encoding == Encoding::ASCII_8BIT) ? encode_binary(value) : value
      else
        value
    end
  end

  def self.encode_binary(binary_string)
    Base64.urlsafe_encode64(binary_string)
  end

  attr_reader :resource, :resource_name
  def initialize(resource_name, resource=nil, dir:)
    @resource_name, @dir = resource_name.to_s, dir
    @resource = resource || unmarshal!
  end

  def save!
    raise ArgumentError unless @dir.kind_of? Pathname
    *files = write_file(@dir / json_filename, to_json),
             write_file(@dir / thrift_serialized_filename, to_serialized_thrift)
    files.each(&:move!) # See write_file's singleton method definition
    self
  end

  def json_filename
    "#{@resource_name}.json"
  end

  def thrift_serialized_filename
    "#{@resource_name}.ruby-thrift.yml"
  end

  def json_file?
    @dir.join(json_filename).file?
  end

  def thrift_serialized_file?
    @dir.join(thrift_serialized_filename).file?
  end

  def as_json
    self.class.sanitize(@resource.as_json)
  end

  def to_json
    JSON.pretty_generate(as_json)
  end

  def to_serialized_thrift
    @resource.to_yaml
  end

  private

  def unmarshal!
    YAML.load_file(@dir / thrift_serialized_filename)
  rescue Errno::ENOENT
    nil
  end

  def write_file(final_path, data)
    Tempfile.new(@resource_name).tap do |tempfile|
      tempfile.write data
      tempfile.close
      tempfile.define_singleton_method(:move!) { FileUtils.mv(self.path, final_path) }
    end
  end

end
