require 'attime'
require 'bigdecimal'
require 'nagios_check'
require 'linear-regression'

module CheckGraphite
  module Projection
    def self.included(base)
      base.on '--projection FUTURE_TIMEFRAME', :default => '2days' do |timeframe|
        options.send('processor=', method(:projected_value))
        options.send('timeframe=', timeframe)
      end
    end

    def projected_value(datapoints)
      ys, xs = datapoints.transpose
      lr = Regression::Linear.new(xs, ys)
      future = CheckGraphite.attime(options.timeframe, xs[-1])
      value = lr.predict(future.to_i)
      p = Regression::CorrelationCoefficient.new(xs, ys).pearson
      store_value options.name, value
      # Unfortunately, nagios_check converts both primary and
      # secondary values to float. Hence manual assignment instead:
      @values['p-value'] = format_float(p.abs)
      store_message "#{options.name}=#{format_float(value)} in #{options.timeframe}"
      return value
    end

    private

     def format_float(v)
       if v.nan?
         'undefined'
       else
         BigDecimal.new(v, 3).to_s('F')
       end
     end
  end
end
