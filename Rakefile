require 'active_record'
require 'yaml'
require 'erb'
require 'logger'

task :default => :migrate

desc "Migrate database"
task :migrate => :environment do
  ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil )
end

task :environment do
  dbconfig = YAML.load(open('config.yml'))
  ActiveRecord::Base.establish_connection(dbconfig['database'])
  ActiveRecord::Base.logger = Logger.new('db/database.log')
end
