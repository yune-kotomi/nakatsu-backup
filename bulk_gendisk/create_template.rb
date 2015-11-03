#!/usr/bin/env ruby
# テンプレート・ディスクイメージを生成する

# ./create_template.rb config /path/to/disk-template
# 指定フォルダにテンプレートを生成する

require 'yaml'
require 'fileutils'
require 'tmpdir'
require 'active_record'
require 'pry'

config = YAML.load(open(ARGV[0]))
disk_max = config['disk']['max'].to_i
Dir.chdir(ARGV[1]) do
  raw_images = (disk_max*1000/3500).times.map do |i|
    n = "disk.img.#{i}"
    system "dd if=/dev/zero bs=1M count=3500 of=#{n}"
    n
  end.sort

  devices = raw_images.map do |n|
    device = `losetup -f`.strip
    system "sudo losetup #{device} #{n}"
    device
  end

  # RAID0を組む
  device = "/dev/md/md0"
  system "sudo mdadm --create #{device} -l linear -n #{devices.size} #{devices.join(' ')}"
  # LUKS暗号化
  system "sudo cryptsetup luksFormat #{device}"
  system "sudo cryptsetup luksOpen #{device} template_disk"
  # キーファイル追加
  system "dd if=/dev/urandom of=luks_key bs=1 count=1024"
  system "sudo cryptsetup luksAddKey #{device} luks_key"
  # EXT4フォーマット
  system "sudo mkfs.ext4 /dev/mapper/template_disk"
  # luksClose
  system "sudo cryptsetup luksClose template_disk"
  # RAID0解放
  system "sudo mdadm --stop #{device}"
  # ループバックデバイスを閉じる
  devices.each {|d| system "sudo losetup -d #{d}" }
end
