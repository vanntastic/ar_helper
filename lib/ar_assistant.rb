module ArAssistant
  
  # common attributes which will not be subject to assignment
  def attrs_to_remove(extra_attrs=[])
    attrs_to_remove =  [:id, :created_at, :updated_at, :created_on, :updated_on,
                        :persistence_token, :single_access_token, :perishable_token,
                        :last_request_at, :last_login_at,:current_login_ip, :last_login_ip, 
                        :logged_in_timeout, :type, :crypted_password, :salt, :remember_token,
                        :remember_token_expires_at]
    attrs_to_remove.push(extra_attrs) unless extra_attrs.blank?
    attrs_to_remove.map &:to_s
  end
  
  
  #grabs the has_many association on the model
   def hm_associations
    hm = []
    associations = self.reflect_on_all_associations
    associations.map {|x| hm << x.name if x.macro.to_s == "has_many"}
    return hm.flatten
   end
   
   def has_associations?; self.reflect_on_all_associations.blank?; end
   
   def build_conditions(conditions)
    conditions = conditions.split(",") if conditions.is_a? String
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