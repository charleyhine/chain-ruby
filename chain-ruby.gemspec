#encoding: UTF-8
Gem::Specification.new do |s|
  s.name          = "chain-ruby"
  s.email         = "ryan@chain.com"
  s.version       = "0.0.9"
  s.date          = "2014-06-19"
  s.description   = "The Official Ruby SDK for Chain's Bitcoin API"
  s.summary       = "The Official Ruby SDK for Chain's Bitcoin API"
  s.authors       = ["Ryan R. Smith"]
  s.homepage      = "http://github.com/chain-engineering/chain-ruby"
  s.license       = "MIT"
  s.files         = ['./lib/chain.rb', 'chain.pem']
  s.require_path  = "lib"
  s.add_development_dependency "rspec"
end
