require 'rb-inotify'
require 'ipaddr'
require 'json'

module Ring
class SQA

  class Nodes
    FILE = '/etc/hosts'
    attr_reader :all

    def run
      Thread.new { @inotify.run }
    end

    def get node
      (@all[node] or {})
    end

    private

    def initialize
      @all = read_nodes
      @inotify = INotify::Notifier.new
      @inotify.watch(File.dirname(FILE), :modify, :create) do |event|
        @all = read_nodes if event.name == FILE.split('/').last
      end
      run
    end

    def read_nodes
      Log.info "loading #{FILE}"
      list = []
      File.read(FILE).lines.each do |line|
        entry = line.split(/\s+/)
        next if entry_skip? entry
        list << entry.first
      end
      nodes_hash list
    rescue => error
      Log.warn "#{error.class} raised with message '#{error.message}' while generating nodes list"
      @all
    end

    def nodes_hash ips, file=CFG.nodes_json
      nodes = {}
      json = JSON.load File.read(file)
      json['results']['nodes'].each do |node|
        addr = CFG.ipv6? ? node['ipv6'] : node['ipv4']
        next unless ips.include? addr
        nodes[addr] = node
      end
      json_to_nodes_hash nodes
    end

    def json_to_nodes_hash from_json
      nodes= {}
      from_json.each do |ip, json|
        node = {
          name: json['hostname'],
          ip:   ip,
          as:   json['asn'],
          cc:   json['countrycode'],
        }
        nodes[ip] = node
      end
      nodes
    end


    def entry_skip? entry
      return true unless entry.size > 2
      return true if entry.first.match(/^\s*#/)
      return true if CFG.hosts.ignore.any?   { |re| entry[2].match Regexp.new(re) }
      return true unless CFG.hosts.load.any? { |re| entry[2].match Regexp.new(re) }

      address = IPAddr.new(entry.first) rescue (return true)
      if CFG.ipv6?
        return true if address.ipv4?
        return true if address == IPAddr.new(CFG.bind.ipv6)
      else
        return true if address.ipv6?
        return true if address == IPAddr.new(CFG.bind.ipv4)
      end
      false
    end
  end

end
end
