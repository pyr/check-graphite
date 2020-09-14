require "nagios_check"
require "json"
require "net/https"
require "check_graphite/version"
require 'check_graphite/projection'

module CheckGraphite

  class Command
    include NagiosCheck
    include Projection

    on "--endpoint ENDPOINT", "-H ENDPOINT", :mandatory
    on "--metric METRIC", "-M METRIC", :mandatory
    on "--from TIMEFRAME", "-F TIMEFRAME", :default => "30seconds"
    on "--name NAME", "-N NAME", :default => :value
    on "--username USERNAME", "-U USERNAME"
    on "--password PASSWORD", "-P PASSWORD"
    on "--dropfirst N", "-A N", Integer, :default => 0
    on "--droplast N", "-Z N", Integer, :default => 0
    on "-I", "--ignore-missing", :default => false do
        options.send("ignore-missing=", true)
    end

    enable_warning
    enable_critical
    enable_timeout

    def check
      uri = URI(URI.encode("#{options.endpoint}?target=#{options.metric}&from=-#{options.from}&format=json"))
      req = Net::HTTP::Get.new(uri.request_uri)

      # use basic auth if username is set
      if options.username
        req.basic_auth options.username, options.password
      end

      res = Net::HTTP.start(uri.host, uri.port, :use_ssl => 'https' == uri.scheme) { |http|
        http.request(req)
      }

      raise "HTTP error code #{res.code}" unless res.code == "200"
      if res.body == "[]"
        if options.send("ignore-missing")
          store_value options.name, 0
          store_message "#{options.name} missing - ignoring"
          return
        else
          raise "no data returned for target"
        end
      end

      datapoints = JSON(res.body).map { |e| e["datapoints"] }.reduce { |a, b| a + b }
      datapoints = datapoints.slice(
        options.dropfirst,
        (datapoints.size - options.dropfirst - options.droplast)
      )

      # Remove NULL values. Return UNKNOWN if there's nothing left.
      datapoints.reject! { |v| v.first.nil? }
      raise "no valid datapoints" if datapoints.size == 0

      processor = options.processor || method(:present_value)
      processor.call(datapoints)
    end

    private

    def present_value(datapoints)
      sum = datapoints.reduce(0.0) {|acc, v| acc + v.first }
      value = sum / datapoints.size
      store_value options.name, value
      store_message "#{options.name}=#{value}"
    end
  end
end
