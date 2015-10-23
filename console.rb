require 'yaml'
require 'fileutils'
require 'tmpdir'
require 'active_record'
require 'pry'

config = YAML.load_file(ARGV[0])
ActiveRecord::Base.establish_connection(config['database'])
Dir::glob('models/*').each {|f| require_relative(f) }

binding.pry
