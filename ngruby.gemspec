# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ngruby/version'

Gem::Specification.new do |spec|
  spec.name          = 'ngruby'
  spec.version       = Ngruby::VERSION
  spec.authors       = ['Rong Zhou', 'Shanghai Qiniu Information Technologies Co., Ltd.']
  spec.email         = ['zhourong@qiniu.com', 'sdk@qiniu.com', 'support@qiniu.com']

  spec.summary       = 'New Generation Qiniu Resource Storage SDK'
  spec.description   = "see:\nhttps://github.com/bachue/ngruby-sdk\n"
  spec.homepage      = 'https://github.com/bachue/ngruby-sdk'
  spec.license       = 'MIT'
  spec.required_ruby_version = '~> 2.4'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rubocop', '~> 0.71'
  spec.add_development_dependency 'webmock', '~> 3.6'
  spec.add_runtime_dependency 'faraday', '~> 0.15'
  spec.add_runtime_dependency 'faraday_middleware', '~> 0.13'
end
