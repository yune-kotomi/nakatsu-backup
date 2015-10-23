#!/usr/bin/env ruby
# 書きだしたBDをマウント

require 'tmpdir'
require 'fileutils'

Dir.chdir(ARGV[0]) do
  images = Dir.glob('*.img.*').sort

  if ARGV[1] == 'stop'
    system "sudo umount /tmp/nakatsu-mount"
    system "sudo cryptsetup luksClose nakatsu"
    system "sudo mdadm --stop /dev/md/md0-nakatsu"
  else
    devices = images.map do |image|
      device = `losetup -f`.strip
      system "sudo losetup #{device} #{image}"
      device
    end
    device = '/dev/md/md0-nakatsu'
    system "sudo mdadm --assemble --force #{device} #{devices.join(' ')}"
    system "sudo cryptsetup luksOpen #{device} nakatsu"
    FileUtils.mkdir('/tmp/nakatsu-mount') unless File.exists?('/tmp/nakatsu-mount')
    system "sudo mount /dev/mapper/nakatsu /tmp/nakatsu-mount"
    system "nautilus /tmp/nakatsu-mount"
  end
end
