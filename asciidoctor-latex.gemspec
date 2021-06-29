# -*- encoding: utf-8 -*-
require File.expand_path('../lib/asciidoctor/latex/version', __FILE__)

Gem::Specification.new do |s|
  s.name          = 'asciidoctor-tex'
  s.version       = Asciidoctor::Tex::VERSION
  s.authors       = ['Nicolas Wanner', 'James Carlson', 'Jakub Jirutka', 'Dan Allen']
  s.email         = 'nicolas.wanner@gmail.com'
  s.homepage      = 'https://github.com/nicowan/asciidoctor-latex'
  s.license       = 'MIT'

  s.summary       = 'Converts AsciiDoc documents to Latex'
  s.description   = 'An extension for Asciidoctor that converts AsciiDoc documents to LaTeX.'

  begin
    s.files       = `git ls-files -z -- */* {CHANGELOG,LICENSE,manual,Rakefile,README}*`.split "\0"
  rescue
    s.files       = Dir['**/*']
  end
  s.executables   = s.files.grep(/^bin\//) { |f| File.basename(f) }
  s.test_files    = s.files.grep(/^(test|spec|features)\//)
  s.require_paths = ['lib']

  s.has_rdoc      = 'yard'

  s.required_ruby_version = '>= 2.0'
  
  s.add_runtime_dependency 'asciidoctor', '~> 2.0', '>= 2.0.0'
  #s.add_runtime_dependency 'opal', '~> 0.6.3'
  s.add_runtime_dependency 'htmlentities', '~> 4.3'

  # specified in the Gemfile for now
  #s.add_development_dependency 'asciidoctor-doctest', '~> 1.5.2.dev'
  #s.add_development_dependency 'rake', '~> 10.0'
  #s.add_development_dependency 'yard', '~> 0.8'
end
