# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'qiniu_ng/version'

Gem::Specification.new do |spec|
  spec.name          = 'qiniu-ng'
  spec.version       = QiniuNg::VERSION
  spec.authors       = ['Rong Zhou', 'Shanghai Qiniu Information Technologies Co., Ltd.']
  spec.email         = ['zhourong@qiniu.com', 'sdk@qiniu.com', 'support@qiniu.com']

  spec.summary       = 'New Generation Qiniu Resource Storage SDK'
  spec.description   = "see:\nhttps://github.com/bachue/ruby-ng-sdk\n"
  spec.homepage      = 'https://github.com/bachue/ruby-ng-sdk'
  spec.license       = 'MIT'
  spec.metadata['yard.run']  = 'yri'
  spec.metadata['source_code_uri']  = 'https://github.com/bachue/ruby-ng-sdk'
  spec.metadata['bug_tracker_uri']  = 'https://github.com/bachue/ruby-ng-sdk/issues'
  spec.metadata['documentation_uri']  = 'https://bachue.github.io/ruby-ng-sdk/'
  spec.required_ruby_version = '~> 2.3'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'carrierwave', '~> 1.0'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'rails', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rspec-eventually', '~> 0.1'
  spec.add_development_dependency 'rubocop', '~> 0.71'
  spec.add_development_dependency 'webmock', '~> 3.6'
  spec.add_development_dependency 'yard', '~> 0.9'
  spec.add_runtime_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_runtime_dependency 'digest-crc', '~> 0.4'
  spec.add_runtime_dependency 'down', '~> 4.8'
  spec.add_runtime_dependency 'faraday', '~> 0.15'
  spec.add_runtime_dependency 'faraday_middleware', '~> 0.13'
  spec.add_runtime_dependency 'ruby-enum', '~> 0.7'
  spec.add_runtime_dependency 'safe_yaml', '~> 1.0'
  spec.add_runtime_dependency 'sqlite3', '~> 1.4'
  if RUBY_PLATFORM == 'java'
    spec.add_runtime_dependency 'jruby-openssl', '~> 0.10'
  else
    spec.add_runtime_dependency 'openssl', '~> 2.1'
  end
end
