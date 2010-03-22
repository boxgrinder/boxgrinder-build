require 'rubygems'

Gem::Specification.new do |s|
  s.platform  = Gem::Platform::RUBY
  s.name      = "boxgrinder-build"
  s.version   = "0.0.1"
  s.author    = "BoxGrinder Project"
  s.homepage  = "http://www.jboss.org/stormgrind/projects/boxgrinder.html"
  s.email     = "info@boxgrinder.org"
  s.summary   = "BoxGrinder Build files"
  s.files     = Dir['lib/**/*.rb'] + Dir['lib/**/*.erb'] + Dir['src/**/*'] + Dir['appliances/*.appl'] + Dir['docs/**/*'] + Dir['extras/*'] << 'README' << 'LICENSE'
  s.executables << 'boxgrinder'


  s.add_dependency('boxgrinder-core', '>= 0.0.1')
  s.add_dependency('aws-s3', '>= 0.6.2')
  s.add_dependency('amazon-ec2', '>= 0.9.6')
  s.add_dependency('net-sftp', '>= 2.0.4')
  s.add_dependency('net-ssh', '>= 2.0.20')
  s.add_dependency('rake', '>= 0.8.7')
end
