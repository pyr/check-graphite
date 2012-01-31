require "nagios_check"
require "json"
require "http"
require "check_graphite/version"

module CheckGraphite

  class Command
    include NagiosCheck

    on "--endpoint ENDPOINT", "-H ENDPOINT", :mandatory
    on "--metric METRIC", "-M METRIC", :mandatory
    on "--from TIMEFRAME", "-F TIMEFRAME", default: "30seconds"
    on "--name NAME", "-N NAME", default: :value

    enable_warning
    enable_critical
    enable_timeout

    def check
      data = Http.get "#{options.endpoint}?target=#{options.metric}&from=-#{options.from}&format=json"
      raise "no such metric registered" unless data.length > 0
      res = data.first["datapoints"].reduce({:sum => 0.0, :count => 0}) {|acc, e|
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
