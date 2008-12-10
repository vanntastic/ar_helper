require 'test/unit'
require 'rubygems'
require 'test/spec'
require 'active_record'
require 'active_record/fixtures'
require File.dirname(__FILE__) + '/../lib/ar_helper'

db_config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.establish_connection db_config["ar_helper"]

# Comment out to view AR schema statments
$stdout = StringIO.new

def create_schema
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define :version => 1 do
     create_table "people", :force => true do |t|
       t.column "name",  :text
       t.column "email", :text
       t.timestamps
     end
     
     create_table "dummies", :force => true do |t|
       t.column :nothing_special, :string
     end
  end
  
end

def drop_models
  ActiveRecord::Base.connection.drop_table :people
end

def load_fixtures
  fixture_path = File.dirname(__FILE__) + '/fixtures/people.yml'
  Fixtures.create_fixtures fixture_path, ActiveRecord::Base.connection.tables
end

# mock models for testing
class Person < ActiveRecord::Base; end
class Dummy < ActiveRecord::Base; end