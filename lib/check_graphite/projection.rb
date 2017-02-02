require 'attime'
require 'bigdecimal'
require 'nagios_check'
require 'linear-regression'

module CheckGraphite
  module Projection
    def self.included(base)
      base.on '--projection FUTURE_TIMEFRAME', :default => '2days' do |timeframe|
        options.send(:processor=, method(:projected_value))
        options.send(:timeframe=, timeframe)
      end

      base.on '--p-threshold VALUE' do |raw_threshold|
        begin
          threshold = Float(raw_threshold)
          raise "Expected 0 <= #{threshold} <= 1" unless threshold >= 0 && threshold <= 1
          options.send(:p_threshold=, threshold)
        rescue ArgumentError
          raise "Expected #{raw_threshold} to be a float"
        end
      end
    end

    def projected_value(datapoints)
      ys, xs = datapoints.transpose
      lr = Regression::Linear.new(xs, ys)
      future = CheckGraphite.attime(options.timeframe, xs[-1])
      value = lr.predict(future.to_i)
      p = Regression::CorrelationCoefficient.new(xs, ys).pearson.abs
      if is_good_p?(p)
        store_value options.name, value
        store_message "#{options.name}=#{format_float(value)} in #{options.timeframe}"
      else
        store_value options.name, nil
        store_message "No projection on #{options.name}; p = #{format_float(p)} < #{options.p_threshold}"
      end
      # Unfortunately, nagios_check converts both primary and
      # secondary values to float. Hence manual assignment instead:
      @values['p-value'] = format_float(p)
      return value
    end

    private

    def is_good_p?(p)
      options.p_threshold.nil? || p.nan? || p >= options.p_threshold
    end

    def format_float(v)
      if v.nan?
        'undefined'
      else
        BigDecimal.new(v, 3).to_s('F')
      end
    end
  end
end
