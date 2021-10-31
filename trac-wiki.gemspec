require File.dirname(__FILE__) + '/lib/trac-wiki/version'
require 'date'

Gem::Specification.new do |s|
  s.name = 'trac-wiki'
  s.version = TracWiki::VERSION
  s.date = Date.today.to_s
  s.licenses = ['GPL-2.0+']

  s.authors = ['Vitas Stradal']
  s.email = ['vitas@matfyz.cz' ]
  s.summary = 'Trac Wiki markup language'
  s.description = 'TracWiki markup language render (http://trac.edgewall.org/wiki/WikiFormatting ).'
  s.extra_rdoc_files = %w(README)
  s.rubyforge_project = s.name

  s.files = `git ls-files`.split("\n")
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)

  s.homepage = 'http://github.com/vitstradal/trac-wiki'

  s.add_development_dependency('bacon', '~> 0')
  s.add_development_dependency('rake',  ">= 12.3.3" )
end
