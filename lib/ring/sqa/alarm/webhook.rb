require 'net/http'
require 'timeout'

module Ring
class SQA
class Alarm

  class Webhook
    TIMEOUT = 10
    def send opts
      cfg  = CFG.webhook
      json = JSON.pretty_generate( {
        :alarm_buffer => opts[:alarm_buffer].exceeding_nodes,
        :nodes        => opts[:nodes].all,
        :short        => opts[:short],
        :long         => opts[:long],
        :status       => opts[:status],
        :afi          => opts[:afi],
      })
      post json, cfg.url, cfg.authorization?
    rescue => error
      Log.error "Webhook send raised '#{error.class}' with message '#{error.message}'"
    end

    private

    def post json, url, authorization
      Thread.new do
        begin
          Timeout::timeout(TIMEOUT) do
            uri = URI.parse url
            http = Net::HTTP.new uri.host, uri.port
            http.use_ssl = true if uri.scheme == 'https'
            req = Net::HTTP::Post.new(uri.request_uri, { 'Content-Type' => 'application/json' })
            if authorization
              req['Authorization'] = authorization
            end
            req.body = json
            _response = http.request req
          end
        rescue Timeout::Error
          Log.error "Webhook post timed out"
        rescue => error
          Log.error "Webhook post raised '#{error.class}' with message '#{error.message}'"
        end
      end
    end
  end

end
end
end
