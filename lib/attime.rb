# This helper is trying to replicate the relative parts of
# https://github.com/graphite-project/graphite-web/blob/master/webapp/graphite/render/attime.py

module CheckGraphite
  DAY = 86400
  UNITS = {
    "s" => "second",
    "se" => "second",
    "sec" => "second",
    "second" => 1,
    "seconds" => "second",

    "min" => "minute",
    "minute" => 60,
    "minutes" => "minute",

    "ho" => "hour",
    "hour" => 3600,
    "hours" => "hour",

    "d" => "day",
    "da" => "day",
    "day" => DAY,
    "days" => "day",

    "week" => 7 * DAY,
    "weeks" => "week",

    "m" => nil, # min or mon?
    "mon" => "month",
    "month" => 30 * DAY,
    "months" => "month",

    "y" => "year",
    "ye" => "year",
    "year" => 365 * DAY,
    "years" => "year",
  }
  EXPR = /([+-])?([0-9]*)(.*)/

  def self.attime(text, time = Time.now)
    match = EXPR.match(text)
    raise "Unparseable time period #{text}" unless match
    sign, scalar, unit = match[1..3]
    raise "Missing scalar in time #{text}" if scalar == ""
    raise "Missing unit in #{text}" if unit == ""
    time + Integer(scalar) * lookup(unit) * (sign == "-" ? -1 : 1)
  end

  private

  def self.lookup(unit)
    x = UNITS[unit.downcase]
    raise "Bad unit #{unit}" unless x
    if x.is_a? String
      lookup(x)
    else
      x
    end
  end
end
