#!/usr/bin/env ruby
# 回収していないスナップショットを回収する

require 'yaml'
require 'fileutils'
require 'active_record'
require 'pry'

config = YAML.load(open(ARGV[0]))
ActiveRecord::Base.establish_connection(config["database"])
Dir::glob('models/*').each {|f| require_relative(f) }


Dir.chdir(config['destination']) do
  snapshot_pathes = Dir::glob('*').sort.map{|path| File.expand_path(path) }

  snapshot_pathes.select{|path| Snapshot.where(:path => File.expand_path(path)).count == 0 }.each do |current_path|
    puts "snapshot: #{current_path}"
    if snapshot_pathes.index(current_path) == 0
      prev_path = nil
    else
      prev_path = snapshot_pathes[snapshot_pathes.index(current_path) - 1]
    end
    puts "previous snapshot: #{prev_path}"

    files = Dir::glob(File.join(current_path, '/**/*')).
      reject{|f| File.directory?(f) }.
      map{|f| f.sub(current_path, '') }.
      reject do |filename|
        if prev_path.nil?
          false
        else
          current_filename = File.join(current_path, filename)
          prev_filename = File.join(prev_path, filename)
          # inode番号が同じものは以前のスナップショットと同様のもの
          File.exists?(prev_filename) && File.stat(current_filename).ino == File.stat(prev_filename).ino
        end
      end

    snapshot = Snapshot.new(:path => current_path)
    snapshot.save

    files.each do |filename|
      src_fname = File.join(config['source'], filename)
      puts "source: #{src_fname}"
      begin
        path = Path.transaction do
          path = Path.where(:path => src_fname).first
          if path.nil?
            path = Path.new(:path => src_fname)
            path.save
          end
          path
        end
        history = History.new(:file_path => File.join(current_path, filename))
        history.path = path
        history.snapshot = snapshot
        history.save
      rescue ActiveRecord::StatementInvalid => e
        puts "invalid filename: #{src_fname}"
      end
    end
  end

  GC.start
end
