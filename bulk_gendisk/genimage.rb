#!/usr/bin/env ruby
# ディスクイメージを生成する

# ./genimage.rb [config-name] [template] [disk-name-prefx] [start] [end] [destination]
# ""#{disk-name-prefx}N"のISOイメージを生成する

require 'yaml'
require 'fileutils'
require 'tmpdir'
require 'active_record'
require 'pry'

# 書き出し済みのファイル一覧(History)を出力
def written_histories(disk_name)
  disk = Disk.where(:name => disk_name).first
  disk.histories.includes(:snapshot)
end

# 指定したサイズに収まる新規ファイル一覧
def new_histories(size)
  ret = []
  total = 0
  100.times do |i|
    candicates = History.
      includes(:snapshot).
      order('created_at').
      where("disk_id is null").
      where("(select count(*) from histories h2 where h2.digest=histories.digest AND not(h2.disk_id is null)) = 0").
      limit(10000).
      offset(10000*i).map do |history|

      next if total + history.size > size
      total += history.size
      history
    end.compact
    break if candicates.empty?

    ret += candicates
  end

  ret
end

def create_disk(template, disk_max, name, destination)
  if Disk.where(:name => name).count > 0
    # 既存の再生成
    histories = written_histories(name)
    disk = Disk.where(:name => name).first
  else
    # 新規生成
    histories = new_histories(disk_max*1000**3)
    disk = Disk.new(:name => name)
    disk.save
  end
  raise 'no files to write!' if histories.empty?

  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      # ディスクイメージの生成
      raw_images = Dir.glob(File.join(template, 'disk.img.*')).map do |src|
        n = File.basename(src).sub('disk', name)
        FileUtils.cp(src, n)
        n
      end.sort

      devices = raw_images.map do |n|
        device = `losetup -f`.strip
        system "sudo losetup #{device} #{n}"
        device
      end

      # RAID0を組む
      device = "/dev/md/md0"
      system "sudo mdadm --assemble --force #{device} #{devices.join(' ')}"
      # キーファイルでアンロック
      system "sudo cryptsetup luksOpen --key-file #{File.join(template, 'luks_key')} #{device} copied_disk"
      # マウント
      FileUtils.mkdir('mountpoint')
      system "sudo mount /dev/mapper/copied_disk mountpoint"
      system "sudo chown user mountpoint"

      puts "copying files"
      begin
        histories.each do |history|
          path = File.dirname(File.join(File.join('mountpoint', history.snapshot.name), history.relative_path))
          unless File.exists?(path)
            FileUtils.mkdir_p(path)
          end

          begin
            FileUtils.cp(history.file_path, path)
            history.update_attribute(:disk, disk) if history.disk.blank?
          rescue Errno::ENOSPC => e
            if history.disk.present?
              puts "以前に書き込んだファイル #{history.file_path} が今回は書き込めません"
              raise "以前に書き込んだファイル #{history.file_path} が今回は書き込めません"
            end
            raise e
          end
        end
      rescue Errno::ENOSPC => e
        # もう入らないので抜ける
        puts e.inspect
      end
      # アンマウント
      system "sudo umount mountpoint"
      # luksClose
      system "sudo cryptsetup luksClose copied_disk"
      # キーファイルを外す
      system "sudo cryptsetup luksRemoveKey #{device} #{File.join(template, 'luks_key')}"
      # RAID0解放
      system "sudo mdadm --stop #{device}"
      # ループバックデバイスを閉じる
      devices.each {|d| system "sudo losetup -d #{d}" }

      # ISOイメージ生成
      system "mkisofs -L -R -o #{File.join(destination, "#{name}.iso")} -V #{name} #{name}.img.*"
    end
  end
end

system "sudo id"

config = YAML.load(open(ARGV[0]))
ActiveRecord::Base.establish_connection(config['database'])
Dir::glob('models/*').each {|f| require_relative(File.join('..', f)) }

disk_max = config['disk']['max'].to_i
template = ARGV[1]
disk_name_prefix = ARGV[2]
from = ARGV[3].to_i
to = ARGV[4].to_i
destination = ARGV[5]

(from..to).each {|i| create_disk(template, disk_max, "#{disk_name_prefix}#{i}", destination) }
