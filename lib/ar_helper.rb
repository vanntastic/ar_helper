# DEPENDS on map_by_method # => sudo gem install map_by_method
require 'map_by_method'

module ArHelper
  
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
     # provides a params hash with generated data which will can useful for testing
     # USAGE : 
     # Model.to_params :name_of_params_hash # => :name_of_params_hash (defaults to :params)
     #         to override the params hash, just pass a hash list of attributes :
     #         Model.to_params.merge(:my_options)
     def to_params(params_name="params")
       @@params_var = params_name.to_sym
       # attributes = self.columns.map {|c| c.name.to_sym}
       p_hsh = {}
       self.columns.map {|a| p_hsh[a.name.to_sym]=generate_val(a)}
       p_hsh.delete :id
       params = {@@params_var => p_hsh}  

       params.instance_eval do
         #overrides Hash#merge method by merging just the sub hash and not the main one
         def merge(options={})
           self[@@params_var].update(options)
           return self
         end
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
     
     # search columns using sql LIKE operator with % wildcard character
     # USAGE : Model.search criteria, column_names, conditions # => defaults to all columns 
     #         minus date columns
     # TODO : add error checking
     # TODO : add tests 
     def search(criteria, columns=self.column_names,conditions=nil)
       @@klass = self
       # refining the columns param
       columns = self.column_names if columns == :all
       # columns = [columns] if columns.is_a? String
       columns = columns.split(",") if columns.is_a? String
       keys_to_remove = ["created_on","created_at","updated_on","updated_at","id"]
       keys_to_remove.each {|key| columns.delete key}
       sql = ""
       #allows you to pass columns as String instead of explicitly wrapping it into an array
       columns.each do |column|
        sql << "#{column} LIKE ?"
        sql << " OR " unless column == columns.last
       end
       # concatenate extra conditions if one was passed
       sql << build_sql(conditions) unless conditions.nil?
       sql = [sql]
       criterias = ["%#{criteria}%"]*columns.length
       search_results = find :all, :conditions => sql.concat(criterias)
       
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
     
     #grabs the has_many association on the model
     def hm_associations
      hm = []
      associations = self.reflect_on_all_associations
      associations.map {|x| hm << x.name if x.macro.to_s == "has_many"}
      return hm.flatten
     end
     
     protected
       def has_associations?; self.reflect_on_all_associations.blank?; end
       
       def build_sql(conditions)
        conditions = [conditions] if conditions.is_a? String
        sql = ""
        conditions.each { |condition| sql << " AND #{condition}" }
        sql
       end
       
       # generates a random date
       # you can simply call it like random_date to generate a simple random date
       # otherwise you can pass hash values to generate like
       #       random_date :year => your_year, :month => range_of_month, 
       #                   :day => range_of_days, 
       #                   :format => format_string (same as Date#strftime)
       #                   :return_date => true/false (will return a date object if true)
       def random_date(options={})
         options[:year] ||= Time.now.year
         options[:month] ||= rand(12)
         options[:day] ||= rand(31)
         options[:format] ||= "%Y-%m-%d"
         options[:return_date] ||= false

         str = "#{options[:year]}-#{options[:month]}-#{options[:day]}".to_date.strftime options[:format]
         date = "#{options[:year]}-#{options[:month]}-#{options[:day]}".to_date

         options[:return_date] ? date : str
       # if the date is invalid let's re-try we'll probably get a valid date the 
       # next time around
       # we're passing format because the format needs to stay consistent  
       rescue ArgumentError
         random_date :format => options[:format]
       end

       # generates a random string
       # thanks to snippet : http://snippets.dzone.com/posts/show/2111
       def random_string(size=25)
         (1..size).collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join
       end

       def generate_val(col)
         limit = col.type == :text ? 100 : col.limit
         # date = col.name == "created_on" ? nil : random_date
         return random_date if [:datetime,:date,:timestamp].include? col.type
         return rand(limit) if [:integer,:decimal].include? col.type
         return random_string if [:string, :text].include? col.type
         return col.default if col.type == :boolean
       end
  end
  
  module Sugar
    # TODO : write tests for these methods 
    # TODO : make sure that these methods work with or without created_at... 
    
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
    # TODO : add in an option for passing in a number for the limit
    def first(model, options={})
      options[:order] = "created_at DESC"
      options[:limit] = 1
      qry = modelize(model, :first, options)
      return qry.is_a?(Array) ? qry.first : qry 
    end
    
    # a nice way to get the last record 
    # instead of User.find(:all, :order => "created_at ASC", :limit => 5)
    # TODO : add in an option for passing in a number for the limit
    def last(model, options={})
      options[:order] = "created_at ASC"
      options[:limit] = 1
      
      qry = modelize(model, :all, options)
      return qry.is_a?(Array) ? qry.first : qry
    end
    
    # a quick way to get the last five records in a model
    # USAGE : recent :users # => User.find(:all, :order => "created_by DESC", :limit => 5)
    # you can also use associations if you pass a string:
    # EX : recent 'current_user.posts' 
    # => current_user.posts.find(:all, :order => "created_at DESC", :limit => 5)
    def recent(model, options={})
      options[:order] = "created_at DESC"
      options[:limit] = 5
      
      qry = modelize(model, :all, options)
    end
    
    def modelize(model, type, options)
      if model.is_a? Symbol
        qry = eval(model.to_s.singularize.camelize)
        return qry.find(type, options)
      elsif model.is_a? String
        return eval(model).find(type, options)
      end
    end
  end
  
end