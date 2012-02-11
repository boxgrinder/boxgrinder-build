if ENV['COVERAGE']
  require 'simplecov'

  FILTER_DIRS = ['spec']

  SimpleCov.start do
    FILTER_DIRS.each{ |f| add_filter f }
  end
end
