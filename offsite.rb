#!/usr/bin/env ruby
# オフサイトバックアップを実行する

require 'yaml'
require 'fileutils'
require 'active_record'
require 'tmpdir'
require 'pry'

config = YAML.load(open(ARGV[0]))
ActiveRecord::Base.establish_connection(config["database"])
Dir::glob('models/*').each {|f| require_relative(f) }

begin
  Dir.chdir(config['offsite']['base']) {}
  # ベースバックアップ用ストレージがマウントされている場合、
  # 最新のスナップショットでベースバックアップの更新を行う
  latest_snapshot = Snapshot.order('created_at desc').limit(1).first
  rsync = "rsync -av --delete \"#{File.join(latest_snapshot.path, '/')}\" \"#{config['offsite']['base']}\""
  puts rsync
  system rsync
  Snapshot.transaction do
    Snapshot.where(:offsite_base => true).each{|s| s.update_attribute(:offsite_base, false) }
    latest_snapshot.update_attribute(:offsite_base, true)
  end

  # 差分を削除
  Dir.chdir(config['offsite']['diff']) do
    Dir.glob('*').each do |dir|
      puts "rm rf #{dir}"
      FileUtils.rm_rf(dir)
    end
  end

rescue Errno::ENOENT
  # ベースからの差分をリモートに格納する
  Dir.chdir(config['offsite']['diff']) do
    exists = Dir.glob('*')
    base = Snapshot.where(:offsite_base => true).first
    # ベースバックアップ実行後に生成され保存していないスナップショット
    snapshots = Snapshot.
      where('id > ?', base.id).
      order('created_at').
      reject{|s| exists.include?(s.name) }

    snapshots.each do |snapshot|
      snapshot.histories.each do |history|
        dest_path = File.dirname(File.join(snapshot.name, history.relative_path))
        if File.exists?(history.file_path)
          FileUtils.mkdir_p(dest_path)
          FileUtils.cp(history.file_path, dest_path)
        end
      end
    end
  end
end
