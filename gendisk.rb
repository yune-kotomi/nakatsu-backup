#!/usr/bin/env ruby
# ディスクイメージを生成する

# ./gendisk.rb [config-name] [new-disk-name]
# 新規ファイルを入れた新規ディスクを生成する
# ./gendisk.rb [config-name] [disk-name]
# 指定した名前のディスクを再度生成する
# ./gendisk.rb [config-name] [disk-name] append
# 指定した名前のディスクに新規ファイルを追加して生成する

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
      offset(10000 * i).map do |history|

      next if total + history.size > size
      total += history.size
      history
    end.compact
    break if candicates.empty?

    ret += candicates
  end

  ret
end

config = YAML.load(open(ARGV[0]))
ActiveRecord::Base.establish_connection(config['database'])
Dir::glob('models/*').each {|f| require_relative(f) }

disk_max = config['disk']['max'].to_i
if Disk.where(:name => ARGV[1]).count > 0
  # 既存の再生成
  histories = written_histories(ARGV[1])
  if ARGV[2] == 'append'
    histories = histories + new_histories(disk_max*1000**3 - histories.map(&:size).reduce(:+))
  end

  disk = Disk.where(:name => ARGV[1]).first
else
  # 新規生成
  histories = new_histories(disk_max*1000**3)
  disk = Disk.new(:name => ARGV[1])
  disk.save
end
raise 'no files to write!' if histories.empty?

Dir.mktmpdir do |dir|
  Dir.chdir(dir) do
    # ディスクイメージの生成
    devices = (disk_max*1000/3500).times.map do |i|
      system "dd if=/dev/zero bs=1M count=3500 of=#{disk.name}.img.#{i}"
      device = `losetup -f`.strip
      system "sudo losetup #{device} #{disk.name}.img.#{i}"
      device
    end

    # RAID0を組む
    device = "/dev/md/md0-#{disk.name}"
    system "sudo mdadm --create #{device} -l linear -n #{devices.size} #{devices.join(' ')}"
    # LUKS暗号化
    system "sudo cryptsetup luksFormat #{device}"
    system "sudo cryptsetup luksOpen #{device} #{disk.name}"
    # EXT4フォーマット
    system "sudo mkfs.ext4 /dev/mapper/#{disk.name}"
    # マウント
    FileUtils.mkdir('mountpoint')
    system "sudo mount /dev/mapper/#{disk.name} mountpoint"
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
            raise "以前に書き込んだファイル #{history.file_path} が今回は書き込めません"
          end
          raise e
        end
      end
    rescue Errno::ENOSPC => e
      # もう入らないので抜ける
      puts e.inspect
    rescue => e
      binding.pry
    end
    # アンマウント
    system "sudo umount mountpoint"
    # luksClose
    system "sudo cryptsetup luksClose #{disk.name}"
    # RAID0解放
    system "sudo mdadm --stop #{device}"
    # ループバックデバイスを閉じる
    devices.each {|d| system "sudo losetup -d #{d}" }

    # ISOイメージ生成
    system "mkisofs -L -R -o #{disk.name}.iso -V #{disk.name} #{disk.name}.img.*"
    # リカバリレコード追加
    system "dvdisaster -c -i #{disk.name}.iso -mRS02 -n #{config['disk']['redundancy']}"
    # ディスク書き込み
    unless system "growisofs -dvd-compat -Z #{config['disk']['device']}=#{disk.name}.iso -use-the-force-luke=spare:none"
      # イメージ書き込みに失敗した場合、/tmpにisoイメージを移動してから抜ける
      FileUtils.mv("#{disk.name}.iso", Dir.tmpdir)
    end
  end
end
