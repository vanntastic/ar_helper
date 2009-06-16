ArHelper
========

These are some common extractions from methods that I consistently use when I write rails apps. I
use them for anything Active Record related. They are mainly simplifications of patterns you could
otherwise do in plain AR.

DEPENDENCIES
------------
- map_by_method # => sudo gem install map_by_method

ArHelper::Sugar
===============

ArHelper::Sugar adds some convenient abstraction methods to ActionView and
ActionController, that makes querying a bit more pleasing and grammatically 
correct (IMO). This looks beatiful with Dr Nic's map_by_method gem
for example instead of User.find(:all).map_by_name, you can do all(:users).map_by_name

all :name_of_model, options={}
------------------------------
An abstraction of Model#find :all, options.

Example:

      all(:users, :order => "created_at") # => User.find :all, :order => "created_at"

first :name_of_model, options={}      
--------------------------------
An abstraction of Model#find(:all, options).first

Example:

      first(:user, :order => "created_at") # => User.find(:all, :order => "created_at").first
      
last :name_of_model, options={}
-------------------------------
An abstraction of Model#find(:all, options).first

Example:

      last(:user, :order => "created_at") # => User.find(:all, :order => "created_at").last

recent :name_of_model, options={}
---------------------------------
An abstraction of Model#find(:all, :order => "created_at DESC", :limit => 5)
      
Example:

      recent(:users) # => User.find(:all, :order => "created_at DESC", :limit => 5)

Usage in script/console
-----------------------

If you want to use these methods in the console, simply copy and paste this into your .irbrc:

      # check to see if the ar_helper plugin is installed
      def ar_helper_exists?; File.exists?("vendor/plugins/ar_helper"); end

      def require_and_load_ar_helper
          require "vendor/plugins/ar_helper/lib/ar_helper"
          extend ArHelper::Sugar if ArHelper.constants.include?("Sugar")
          puts "ArHelper::Sugar methods not loaded ... install ArHelper plugin
                externally..." unless ArHelper.constants.include?("Sugar")
      end

      require_and_load_ar_helper if ar_helper_exists?

Model#to_params param_name, options={}
======================================

Model#to_params generates a params hash of of filled in values for a model... this is 
exceptionally useful when writing tests and you need to pass a params hash to 
an action request, it also automatically removes common unwanted attributes that you might not
want automatically this might be the case if you are using 
[authlogic](http://github.com/binarylogic/authlogic/tree/master) or
[restful_authentication](http://github.com/technoweenie/restful-authentication/tree/master) :

OPTIONS:

    - remove : removes an attributes that you don't want in your params hash
    
EXAMPLES:

    # generating the default values
    # assuming that you have a model named User with an attribute User#first_name
    
        User.to_params # => {:params=> {:first_name => "v3CQJNQrrZMSkeSup1UJu9h1T"}}
    
    # you can also pass in a name to change the params name (default is :params)
    
        User.to_params(:user) # => {:user=> {:first_name => "dAoJr5PpyGMhOwmLuIjpbaBIo"}}

    # if you want to pass your own values to the hash, you can 
    # simply use #merge
    
        User.to_params.merge :first_name => "cool" 
        # => {:params=>{:first_name=>"cool"}}
    
    # Here's an example of how to create dummy data:
    
        User.create User.to_params[:params]
        
    # OR
    
        User.create User.to_params.values

Here's an example of a test suite with the [test/spec](http://github.com/relevance/test-spec/tree/master) and [test/spec/rails](http://github.com/pelargir/test_spec_on_rails/tree/master)
    
        require File.dirname(__FILE__) + '/../test_helper'
        specify "When you manage users, you" do
        
          setup do
            use_controller :users
            @user_params = User.to_params(:user) # => We get params[:user]
          end
          
          it "should create a new user" do
            assert_difference 'User.count' do
              # see how painless this is?
              post :create, @user_params
              has :user
              has_flash :notice
              assigns(:user).should.validate
              response.should.redirect
            end
          end
        
        end

Chained methods
---------------
Some chained methods have been provided to help to clean up and customize your params hash:

Model#to_params#remove
----------------------
Removes additional attributes

Example:

      User.to_params.remove :password, :password_confirmation
      
Model#to_params#merge
---------------------
Merges existing hash values

Example:

      User.to_params.merge :password => "sekrit", :password_confirmation => "sekrit"

Model#to_params#values
----------------------
Returns the values of the hash without the :params parent hash

Example:

    User.to_params.values


Model#search criteria, options={}
=================================

Model#search searches a model using the LIKE operator. Please note that this is basically a wrapper 
around Model#find(:all) with LIKE conditions, I built this simply because I needed a simple method
to query my models without typing too much or worry about customization. If you have more advanced needs to search your models I highly recommend:  [searchlogic](http://github.com/binarylogic/searchlogic/tree/master). I actually revised this plugin because I was somewhat inspired by the elegance of the searchlogic plugin and for the fact that I could not simply do a simple search in searchlogic with OR operators easily enough.

OPTIONS:
--------
  
  - columns : specify the columns(attributes) that you want to search through, this defaults to all the columns (Model#column_names), multiple attributes are passed with a comma delimited list like "first_name, last_name" NOT "first_name", "last_name"
  - conditions : allows you specify additional conditions, NOTE: this is not the same as the AR conditions hash, you **CANNOT** pass in hash conditions ... (yet)
  - modifier : pass in either :or or :and, this defaults to :or
  - remove : specify the columns(attributes) that you want to remove from the search, you can also pass remove a comma delimited list of attributes

EXAMPLES :
----------

    # default use is searching through all columns
    
        User.search "something" 
        # => User.find :all, 
        #   :conditions => ["first_name LIKE ? OR last_name LIKE ?",
        #                   '%something%','%something%']
        
    # change the modifier to AND    
    
        User.search "something", :modifier => :and
        # => User.find :all, 
        #   :conditions => ["first_name LIKE ? AND last_name LIKE ?",
        #                   '%something%','%something%']
    
    # what if you want to remove User#last_name?
    
        User.search "something", :remove => "last_name"
        # => User.find :all, 
        #   :conditions => ["first_name LIKE ?", '%something%']
    
    # searching a single column                        
    
        User.search "something", :columns => "first_name" 
        # => User.find :all, :conditions => ["first_name LIKE ?", '%something%']

    # searching multiple columns                                      
    
        User.search "something", :columns => "first_name,last_name"
        # => User.find :all, 
        #    :conditions => ["first_name LIKE ? OR last_name = ?",
        #               '%something%','%something%']


    # searching with an added condition passed as a string for single conditions
    
        User.search "something", :conditions => "active = 1"
        # => User.find :all,
        #    :conditions => ["first_name LIKE ? OR last_name = ? AND active = 1",
        #               '%something%','%something%']

    # searching with multiple conditions
    User.search "something", :conditions => "active = 1,published = 0"
    
        # => User.find :all,
        #    :conditions => ["first_name LIKE ? OR last_name = ? AND active = 1 AND published = 0",
        #               '%something%','%something%']

    # Search also returns added methods for associations on classes, such as :
    # Assuming User#has_many :comments
    
        user = User.search "something", "active = 1"
        user.comments # => returns all related comments
        # the find_many method stores all has_many associations in
        # an array of association hashes
        
        
    # You can also use Model#like instead of Model#search
        
        User.like "something" # => User.search "something"
      
Model#duplicates_on column_name
-------------------------------
Model#duplicates_on finds duplicate values for a column on a model

- User.duplicates_on :first_name # => finds all the duplicates for first_name
