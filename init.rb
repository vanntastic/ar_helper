require 'ar_helper'

ActiveRecord::Base.send :include, ArHelper
ActionView::Base.send :include, ArHelper::Sugar
ActionController::Base.send :include, ArHelper::Sugar
# so we can have some sugar with our tests too only if you are using Rails < 2.3.2
Test::Unit::TestCase.send :include, ArHelper::Sugar if RAILS_GEM_VERSION < '2.3.2'
# make sure that we can make it work with Rails >= 2.3.2
ActionController::TestCase.send :include, ArHelper::Sugar if RAILS_GEM_VERSION >= '2.3.2'
ActiveSupport::TestCase.send :include, ArHelper::Sugar if RAILS_GEM_VERSION >= '2.3.2'