require 'rubygems'

Gem::Specification.new do |s|
  s.platform  = Gem::Platform::RUBY
  s.name      = "boxgrinder-build"
  s.version   = "0.3.1"
  s.author    = "BoxGrinder Project"
  s.homepage  = "http://www.jboss.org/stormgrind/projects/boxgrinder.html"
  s.email     = "info@boxgrinder.org"
  s.summary   = "BoxGrinder Build files"
  s.files     = Dir['lib/boxgrinder-build/**/*'] + Dir['docs/**/*'] << 'README' << 'LICENSE'
  s.executables << 'boxgrinder-build'

  s.add_dependency('boxgrinder-core', '>= 0.0.5')
  s.add_dependency('aws-s3', '>= 0.6.2')
  s.add_dependency('amazon-ec2', '>= 0.9.6')
  s.add_dependency('net-sftp', '>= 2.0.4')
  s.add_dependency('net-ssh', '>= 2.0.20')
  s.add_dependency('rake', '>= 0.8.7')
  s.add_dependency('progressbar', '>= 0.9.0')
  s.add_dependency('commander', '>= 4.0.3')
end
