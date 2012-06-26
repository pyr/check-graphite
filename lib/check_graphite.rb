require "nagios_check"
require "json"
require "net/http"
require "check_graphite/version"

module CheckGraphite

  class Command
    include NagiosCheck

    on "--endpoint ENDPOINT", "-H ENDPOINT", :mandatory
    on "--metric METRIC", "-M METRIC", :mandatory
    on "--from TIMEFRAME", "-F TIMEFRAME", :default => "30seconds"
    on "--name NAME", "-N NAME", :default => :value
    on "--username USERNAME", "-U USERNAME"
    on "--password PASSWORD", "-P PASSWORD"
    on "--dropfirst N", "-A N", Integer, :default => 0
    on "--droplast N", "-Z N", Integer, :default => 0

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

      res = Net::HTTP.start(uri.hostname, uri.port) { |http|
        http.request(req)
      }

      res.code == "200" || raise("HTTP error code #{res.code}")

      datapoints = JSON(res.body).first["datapoints"]                      
      res = datapoints.drop(options.dropfirst)
                      .take(datapoints.length - options.dropfirst - options.droplast)
                      .reduce({:sum => 0.0, :count => 0}) {|acc, e|
        if e[0]
          {:sum => acc[:sum] + e[0], :count => acc[:count] + 1}
        else
          acc
        end
      }
      raise "no valid datapoints" if res[:count] == 0
      store_value options.name, (res[:sum] / res[:count])
    end
  end
end
