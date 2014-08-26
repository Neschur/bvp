#!/usr/bin/env ruby

require 'open-uri'
require 'csv'
require 'optparse'

region = 'ww'
start_date = Date.today.prev_year
end_date = Date.today

OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-s", "--start-date Date", "date of beginning") do |v|
    start_date = Date.parse(v)
  end

  opts.on("-e", "--end-date Date", "date of ending") do |v|
    end_date = Date.parse(v)
  end

  opts.on("-r", "--region ww/BY/etc", "region, default ww") do |v|
    region = v
  end
end.parse!

meta = {
  'Chrome' => [30, 35],
  'Firefox' => [5, 24, 31],
  'IE' => [8, 9, 10],
  'Safari' => [6.0, 7.0],
  'Opera' => [12, 15],
}

browsers = {}

months = (start_date..end_date).select{|date| date.day == 1}

months.each do |date|
  year = date.year
  month = date.month
  open("http://gs.statcounter.com/chart.php?"\
    "bar=1&device=Desktop&device_hidden=desktop&statType_hidden=browser_version&"\
    "region_hidden=#{region}&granularity=monthly&statType=Browser%20Version&"\
    "fromInt=#{year}#{month}&toInt=#{year}#{month}&fromMonthYear=#{year}-#{month}&toMonthYear=#{year}-#{month}&"\
    "multi-device=true&csv=1") do |file|
    file.each_line do |line|
      browser, percents = line.split(',')
      bname, bversion = browser.gsub('"','').split(' ')
      percents = percents.to_f
      bversion = bversion.to_f
      next if bname == "Browser"
      versions = meta[bname]
      next if !versions

      push_browser = lambda do |bname|
        browsers[bname] ||= {}
        browsers[bname][year] ||= {}
        browsers[bname][year][month] = ((browsers[bname][year][month] || 0) + percents).round(2)
      end
      version = versions[0]
      push_browser.call("#{bname} < #{version}") if bversion < version && bversion > 0
      versions[1..-1].each_with_index do |version, i|
        push_browser.call("#{bname} #{versions[i]} - #{version}") if bversion < version && bversion >= versions[i]
      end
      version = versions[-1]
      push_browser.call("#{bname} #{version}+") if bversion >= version
    end
  end
end

csv_string = CSV.generate do |csv|
  csv << ['\\'] + months.map(&:to_s)

  browsers.each do |browser_name, stats|
    line = [browser_name]
    months.each do |month|
      line << ((stats[month.year] ? stats[month.year][month.month] : 0) || 0).to_s
    end
    csv << line
  end
end

puts csv_string
