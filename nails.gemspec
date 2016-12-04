# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nails/version'

Gem::Specification.new do |spec|
  spec.name          = "nails"
  spec.version       = Nails::VERSION
  spec.authors       = ["msg7086"]
  spec.email         = ["msg7086@gmail.com"]

  spec.summary       = %q{Create thumbnails for video clips.}
  # spec.description   = %q{}
  spec.homepage      = "https://github.com/msg7086/nails"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'rmagick'
  spec.add_dependency 'streamio-ffmpeg'
  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  # spec.add_development_dependency "rspec", "~> 3.0"
end
