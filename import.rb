require 'yaml'
require 'json'
require 'net/http'

class Program
  attr_reader :filename, :repository, :token

  def initialize(filename, repository, token)
    @filename = filename
    @repository = repository
    @token = token
  end

  def run(custom_params)
    raw_data = YAML.load(File.read(filename))
    data = LabelManager.new

    raw_data['types'].each(&data.method(:append_type))
    raw_data['labels'].each(&data.method(:append))

    custom_params.each do |argument|
      type, labels = argument.split('=')
      if labels
        labels.split(',').each do |label|
          data.append(label, type)
        end
      end
    end

    data.each(&github.method(:import))
  end

  def github
    @github ||= GitHub.new(repository, token)
  end
end

class Label
  attr_reader :name, :hex_color

  def initialize(name, hex_color)
    @name = name
    @hex_color = hex_color
  end

  def to_s
    "<Label name=#{name} hex_color=#{hex_color}>"
  end
end

class LabelManager
  def initialize
    @data = {}
    @types = {}
  end

  def each(&block)
    @data.values.each(&block)
  end

  def append(name, type)
    @data[name] = Label.new(name, color_for_type(type))

    self
  end

  def append_type(name, hex_color)
    @types[name] = hex_color

    self
  end

  private

  def color_for_type(name)
    @types[name]
  end
end

class GitHub
  attr_reader :repository, :token

  def initialize(repository, token)
    @repository = repository
    @token = token
  end

  def import(label)
    request = Net::HTTP::Post.new(uri.path, 'Authorization' => "token #{token}", 'Content-Type' => 'application/json')
    request.body = { name: label.name, color: label.hex_color }.to_json
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  rescue => e
    puts "Failed: #{e.inspect}"
  end

  def uri
    URI("https://api.github.com/repos/#{repository}/labels")
  end
end

Program.new('data.yml', ARGV.shift, ARGV.shift).run(ARGV)
