require 'ar_helper'

ActiveRecord::Base.send :include, ArHelper
ActionView::Base.send :include, ArHelper::Sugar
ActionController::Base.send :include, ArHelper::Sugar
# so we can have some sugar with our tests too
Test::Unit::TestCase.send :include, ArHelper::Sugar