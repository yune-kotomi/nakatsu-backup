#!/usr/bin/env ruby
# ディスクイメージを生成する

# ./gendisk.rb [config-name] [new-disk-name]
# 新規ファイルを入れた新規ディスクを生成する

require 'yaml'
config = YAML.load(open(ARGV[0]))

Dir.chdir(ARGV[1]) do
  Dir.glob('*.iso').each do |f|
    system "dvdisaster -c -i #{f} -mRS02 -n #{config['disk']['redundancy']}"
  end
end
