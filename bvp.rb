#!/usr/bin/env ruby

require 'open-uri'
require 'csv'
require 'optparse'
require 'json'
# require 'byebug'

# Part 1 - initializing
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

  opts.on("-r", "--region ww/by/etc", "region, default ww") do |v|
    region = v.downcase
  end
end.parse!

filename = "meta.#{region}.json"
filename = "meta.default.json" unless File.exist?(filename)

meta = JSON.parse(IO.read(filename))

browsers = {}

months = (start_date..end_date).select{|date| date.day == 1}

# Part 2 - calculation version

months.each do |date|
  year = date.year
  month = date.month

  ->{
    data = CSV.parse(
      open("http://gs.statcounter.com/chart.php?"\
        "bar=1&device=Desktop&device_hidden=desktop&statType_hidden=browser_version&"\
        "region_hidden=#{region}&granularity=monthly&statType=Browser%20Version&"\
        "fromInt=#{year}#{month}&toInt=#{year}#{month}&fromMonthYear=#{year}-#{month}&toMonthYear=#{year}-#{month}&"\
        "multi-device=true&csv=1")
    )
    data.shift

    data.each_with_index do |line, index|
      name, version = line[0].split(' ')
      data[index] = {
        :name => name,
        :version => version.to_f,
        :percents => line[1].to_f,
      }
    end
  }.call.each do |browser|
    next unless meta[browser[:name]]

    versions = meta[browser[:name]]

    push_browser = lambda do |key|
      bdata = (browsers[key] ||= {})
      bdata[year] ||= {}
      bdata[year][month] = ((bdata[year][month] || 0) + browser[:percents]).round(2)
    end

    bname = browser[:name]
    bversion = browser[:version]

    version = versions[0]
    version = version['version'] if version.is_a?(Hash)
    push_browser.call([bname, 0, version]) if bversion < version && bversion > 0
    versions[1..-1].each_with_index do |version, i|
      version = version['version'] if version.is_a?(Hash)
      version_named = version
      if versions[i].is_a?(Hash)
        versionsi = versions[i]['version']
        version_named = versionsi if versions[i]['single']
      else
        versionsi = versions[i]
      end
      push_browser.call([bname, versionsi, version_named]) if bversion < version && bversion >= versionsi
    end
    version = versions[-1]
    push_browser.call([bname, version]) if bversion >= version
  end
end

# Part 3 - Sorting, humanize, output

sorted_browsers = browsers.sort do |a1, a2|
  result = a1.first.first[0].ord - a2.first.first[0].ord
  result = a1.first[1] - a2.first[1] if result == 0
  result
end

browsers = {}

sorted_browsers.each do |key, value|
  if key.length == 2
    new_key = "#{key[0]} #{key[1]}+"
  elsif key[1] == 0
    new_key = "#{key[0]} < #{key[2]}"
  elsif key[1] == key[2]
    new_key = "#{key[0]} #{key[1]}"
  else
    new_key = "#{key[0]} #{key[1]} - <#{key[2]}"
  end

  browsers[new_key] = value
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
