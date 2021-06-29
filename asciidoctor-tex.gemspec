Gem::Specification.new do |s|
  s.name        = 'asciidoctor-tex'
  s.version     = '0.1.0'

  s.authors     = ["Nicolas Wanner", 'James Carlson', 'Jakub Jirutka', 'Dan Allen']
  s.email       = 'nicolas.wanner@gmail.com'

  s.summary     = "Converts asciidoc document in LaTeX"
  s.description = "This backend supports almost all asciidoc syntax. Event table, images, listing and admonitions."
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/nicowan/asciidoctor-latex'

  s.bindir      = 'bin'
  s.executables = ['asciidoctor-tex']
  s.files       = Dir[ "bin/**/*", "lib/**/*", "data/**/*"]

  s.add_dependency 'htmlentities', '~> 4.3'

  #s.add_development_dependency 'asciidoctor-doctest', '= 2.0.0.beta.7'
end