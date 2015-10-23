require 'yaml'
require 'fileutils'
require 'tmpdir'
require 'active_record'
require 'pry'

config = YAML.load_file( 'config/database.yml' )
ActiveRecord::Base.establish_connection(config["db"][ENV['ENV'] || 'development'])
ActiveRecord::Base.logger = Logger.new('db/database.log')
Dir::glob('models/*').each {|f| require_relative(f) }

binding.pry
