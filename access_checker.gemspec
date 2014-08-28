# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'access_checker/version'

Gem::Specification.new do |spec|
  spec.name          = "access_checker"
  spec.version       = AccessChecker::VERSION
  spec.authors       = ["Kristina Spurgin"]
  spec.email         = ["TODO: ADD EMAIL"]
  spec.summary       = %q{A script to check for full-text access to e-resource titles.}
  spec.description   = %q{A simple JRuby script to check for full-text access to e-resource titles. Plain old URL/link checking won't alert you if one of your ebook links points to a valid HTML page reading "NO ACCESS." This script will.}
  spec.homepage      = ""
  spec.license       = "GNU General Public License v3 or later"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.platform = 'java'

  spec.add_runtime_dependency 'celerity', '~> 0.9.2'
  spec.add_runtime_dependency 'highline', '~> 1.6.21'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
end
