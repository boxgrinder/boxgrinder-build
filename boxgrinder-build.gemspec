require 'rubygems'

Gem::Specification.new do |s|
  s.platform  = Gem::Platform::RUBY
  s.name      = "boxgrinder-build"
  s.version   = "0.4.2"
  s.author    = "BoxGrinder Project"
  s.homepage  = "http://www.jboss.org/stormgrind/projects/boxgrinder.html"
  s.email     = "info@boxgrinder.org"
  s.summary   = "BoxGrinder Build files"
  s.files     = Dir['lib/**/*'] + Dir['docs/**/*'] << 'README' << 'LICENSE'
  s.executables << 'boxgrinder-build'

  s.add_dependency('boxgrinder-core', '>= 0.0.12')
  s.add_dependency('commander', '>= 4.0.3')
end
