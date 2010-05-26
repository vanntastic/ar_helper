# DEPENDS on map_by_method # => sudo gem install map_by_method
require 'rubygems'
require 'map_by_method'
require File.dirname(__FILE__) + '/../lib/ar_assistant'

module ArHelper
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
     include ArAssistant
     
     # Creates a factory to use with tests, can use the same special attributes as to_params, 
     # defaults to using lazy attributes
     # EX: 
     # - jack = User.factory # => creates a factory named jack with lazy attributes
     # - jack = User.factory :name => "jack" # => creates a factory named jack with the name of "jack"
     # 
     # NOTE: this is a simple basic implementation of the factory pattern it doesn't neccesarily
     #       replace fixtures, for a true factory pattern implementation, use factory_girl
     
     def factory(attrs={})
       self.create! to_params.merge(attrs).values
     end
     
     # provides a params hash with generated data which can useful for testing
     # USAGE : 
     # Model.to_params :name_of_params_hash # => :name_of_params_hash (defaults to :params)
     #         to override the params hash, just pass a hash list of attributes :
     #         Model.to_params.merge(:my_options)
     # You can remove attributes from assignment by passing them in the :remove option
     # as an array
     # - User.to_params(:user, :remove => "salt") # => removes the salt attribute 
     #                                                  from assignment
     # - The preferred way to do that now is by using the #remove method :
     # - User.to_params.remove "salt" # => removes the salt attribute from assignment...
     def to_params(params_name=:params, options={})
       options[:remove] = options[:remove].nil? ? attrs_to_remove : attrs_to_remove(options[:remove])
       @@params_var = params_name.to_sym
       p_hsh = {} # => params hash
       self.columns.map {|a| p_hsh[a.name.to_sym]=generate_val(a)}
       # convert it back to symbols since AR likes its column names using strings...
       options[:remove].map!(&:to_sym)
       options[:remove].each {|c| p_hsh.delete c}
       params = {@@params_var => p_hsh}  

       params.instance_eval do
         #overrides Hash#merge method by merging just the sub hash and 
         # not the main one
         def merge(options={})
           self[@@params_var].update(options)
           return self
         end
         
         # removes attrs from params hash
         # EX: User.to_params.remove(:login, :email)
         def remove(*vals)
          vals.each { |val| self[@@params_var].delete val }
          return self
         end
         
         # alias for self[:params]
         def values; return self[@@params_var]; end
         
         alias :hash :values
       end
       
       return params
     end  
     
     # allows you to find the duplicates in a model and alternatively return 
     # all related queries
     # USAGE : Model.duplicates_on :column_name
     # EXAMPLES :
     # == I need to find duplicates in my user model
     #        u = User.duplicates_on :first_name 
     #        # returns an array of duplicates found on the column
     #        # this method also saves the trouble of you having to loop through a find 
     #          method to get related queries
     #        u.results # => returns a hash of the records and attached ids of the duplicates
     #        # u.results[0][:records] # => returns the records in the first match
     #        # u.results[0][:ids] # => array of record ids
     def duplicates_on(column_name)
       @@model = self
       @@column = column_name.to_s
       @@table = self.to_s.pluralize
       duplicates = find_by_sql "SELECT #{@@column}, COUNT(#{@@column}) AS 
                                 duplicates FROM #{@@table}
                                 GROUP BY #{@@column} HAVING(COUNT(#{@@column})>1)"
      
       duplicates.instance_eval do
         
         # returns all the model objects for the duplicates
         def results
          results = [] 
          self.each do |i|
            qry = @@model.find(:all, 
                  :conditions => {@@column.to_sym => i.send(@@column.to_sym)})
            ids = qry.map_by_id
            results << {:records => qry, :ids => ids}
          end
          
          results
         end
         
       end                           
       
       duplicates
     end
     
     # Search columns using sql LIKE operator with % wildcard character
     # USAGE : Model.search criteria, options={}
     #         Model.like criteria, options={}
     # OPTIONS (standard AR find options can be passed too) :
     # 
     # - :columns => A comma delimited list of columns that you want to search through
     # - :conditions => extra conditions that you want to pass, pass in a comma delimited for this
     # - :modifier => this is the OR or the AND in the sql operation
     # - :remove => attrs that you might want to remove, although ArAssistant#attrs_to_remove does
     #              a decent job of removing some common attributes
     # 
     # EXAMPLES :
     # 
     # Simple Search:
     # --
     #  User.search "vann"
     # 
     # Search with conditions:
     # --
     #  User.search "vann", :conditions => "created_at is not null"
     # 
     # Search with AND modifier
     # --
     #  User.search "vann", :modifier => :and
     # 
     # Search with other find options
     # --
     #  User.search "vann", :order => "created_at"
     #
     # Search with specific attributes
     # --
     #  User.search "vann", :columns => "first_name,last_name"
     # 
     # Remove specific attributes
     # --
     #  User.search "vann", :remove => "group_id, books_count"
     # 
     # Advanced search example
     # * notice how the conditions is passed using a comma delimited list, this is because we are
     #   using Array#concat to append the search conditions
     # --
     #  User.search "vann", :order => "created_at", :conditions => "created_at is not null,     
     #                                                              first_name <> 'vanncy'"
     
     def search(criteria, options={})
         options[:columns] ||= self.column_names
         options[:conditions] ||= nil
         # can be :or || :and
         options[:modifier] ||= :or
         options[:remove] = options[:remove].nil? ? attrs_to_remove : attrs_to_remove(options[:remove])
         
         @@klass = self
         
         # refining the columns param
         options[:columns] = options[:columns].split(",") if options[:columns].is_a? String
         options[:remove].each {|key| options[:columns].delete key}
         sql = ""
         
         # allows you to pass columns as String instead of explicitly wrapping it 
         # into an array
         options[:columns].each do |column|
          sql << "#{column} LIKE ?"
          sql << " #{options[:modifier].to_s.upcase} " unless column == options[:columns].last
         end
         
         # concatenate extra conditions if one was passed
         sql << build_conditions(options[:conditions]) unless options[:conditions].nil?
         sql = [sql]
         
         criterias = ["%#{criteria}%"]*options[:columns].length
         # remove invalid ar options
         opts_to_remove = %w(columns modifier remove).map(&:to_sym)
         opts_to_remove.each { |opt| options.delete opt }
         # NOTE : since we concat conditions, remember that you cannot use that standard hash 
         #        conditions anymore
         options.update(:conditions => sql.concat(criterias))
         search_results = find :all, options
         
         search_results.instance_eval do
           # attaches all has_many associations to the search results 
           # in the form of hashes
           # Assume the following model
           # User#has_many comments
           #  1. run the search 
           # =>   u = User.search "something"
           #  2. Get all the comments for this user
           # =>   u.find_many[:comments]
           def find_many
            hm = {}
            @@klass.hm_associations.each do |assoc|
              results = []
              self.each {|x| results << x.send(assoc)}
              hm[assoc] = results.flatten
            end
            hm
           end
           
           # attach has_many associations to the search  
           # so now you can do :
           # u = User.search "something"
           # now you have u.comments (assuming you have has_many :comments)
           @@klass.hm_associations.each do |assoc|
             eval <<-END
               def #{assoc}
                 class << self ; attr_reader :#{assoc} ; end
                 @#{assoc} = find_many[:#{assoc}]
               end
             END
           end
           
           # TODO : add in the belongs_to association in the hash 
         end
         
         search_results
      end
     
      alias :like :search
  end
  
  module Sugar
    # == ArHelper::Sugar
    # it's an quick abstraction layer that allows you to call things in
    # a more grammatically correct format
    # think all(:users) instead of User.find(:all)
    
    # a nice way to call Model#find :all
    # instead of User.find(:all) do all(:users)
    def all(model, options={})
      modelize(model, :all, options)
    end
    
    # a nice way to call Model#find :first
    # instead of User.find(:first) do first(:user)
    def first(model, options={})
      options[:order] = "created_at DESC"
      options[:limit] = 1
      qry = modelize(model, :first, options)
      return qry.is_a?(Array) ? qry.first : qry 
    end
    
    # a nice way to get the last record 
    # instead of User.find(:all, :order => "created_at ASC", :limit => 5)
    def last(model, options={})
      options[:order] = "created_at ASC"
      options[:limit] = 1
      
      qry = modelize(model, :all, options)
      return qry.is_a?(Array) ? qry.first : qry
    end
    
    # a quick way to get the last five records in a model
    # USAGE : recent :users # => User.find(:all, :order => "created_by DESC", :limit => 5)
    # you can also use associations if you pass a string:
    # EX : 
    # recent 'current_user.posts' 
    #     => current_user.posts.find(:all, :order => "created_at DESC", :limit => 5)
    # you can also pass instance variables if they're from AR
    #     recent @users # => returns the first 5 (by default) elems in the array
    # 
    def recent(model, options={})
      options[:order] ||= "created_at DESC"
      options[:limit] ||= 5
      
      qry = modelize(model, :all, options)
    end

    def modelize(model, type, options)
      if model.is_a? Symbol
        qry = eval(model.to_s.singularize.camelize)
        return qry.find(type, options)
      elsif model.is_a? String
        return eval(model).find(type, options)
      elsif model.is_a? Array
        return model[0..options[:limit]]
      end
      
    # in case this model doesn't contain created_at or updated_at
    rescue ActiveRecord::StatementInvalid
      return nil
    rescue NoMethodError
      return nil
    end
    
  end
  
end