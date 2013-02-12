
Gem::Specification.new do |s|
  s.name = %q{log_mixin}
  s.version = '1.1.1'
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.3'

  if s.respond_to? :required_rubygems_version=
    s.required_rubygems_version = Gem::Requirement.new(">= 1.2")
  end
  s.authors = ['Jon Snitow']
  s.email = ['opensource@verticalbrands.com']
  s.date = '2012-10-19'
  s.summary = 'Mixin module for easy logging under various circumstances'
  s.description = <<-EOT
The LogMixin module provides (you guessed it) a mixin to make logging more
convenient.  It is intended to work both with and without Rails, to silence
logging in tests by default but provide access to it when explicitly
requested, to log to stderr (or Rails.logger) by default but accept other
logging targets, and other conveniences.
EOT
  s.files = Dir[
      '{lib}/**/*.rb',
      'LICENSE',
      '*.md',
      'log_mixin.gemspec',
      ]
  s.require_paths = ['lib']

  s.rubyforge_project = 'log_mixin'
  s.rubygems_version = '>= 1.8.6'
  s.homepage = 'http://github.com/apartmentlist'

  s.add_development_dependency('rspec')
  s.add_development_dependency('rr')
end
