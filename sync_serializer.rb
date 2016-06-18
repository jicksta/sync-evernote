# require "json"
require "active_support/json"
require "base64"
require "yaml"

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

  def initialize(resource_name, resource)
    @resource_name = resource_name
    @resource = resource
  end

  def save_into(dir)
    raise ArgumentError unless dir.kind_of? Pathname
    write_file(dir / json_filename, to_json)
    write_file(dir / thrift_serialized_filename, to_serialized_thrift)
  end

  def write_file(path, data)
    path.open("w+") { |f| f.write data }
  end

  def json_filename
    "#{@resource_name}.json"
  end

  def thrift_serialized_filename
    "#{@resource_name}.ruby-thrift.yml"
  end

  def to_json
    JSON.pretty_generate self.class.sanitize(@resource.as_json)
  end

  def to_serialized_thrift
    @resource.to_yaml
  end

end
