#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'
require 'active_support'
require 'active_support/core_ext'

config = YAML.load(open(ARGV[0]))

Dir.chdir(config['destination']) do
  today = Time.now.strftime('%Y%m%d')
  yesterday = Dir::glob("*").sort.last || Time.now.yesterday.strftime('%Y%m%d')

  FileUtils.mkdir(today) unless File.exists?(today)
  today = File.expand_path(today)
  yesterday = File.expand_path(yesterday)
  puts "Today: #{today}"
  puts "Yesterday: #{yesterday}"
  rsync = "rsync -av #{config['excludes'].map{|s| "--exclude='#{s}'" }.join(' ')} --link-dest=\"#{yesterday}\" \"#{config['source']}\" \"#{today}\""
  puts rsync
  system rsync
end
