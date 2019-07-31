# frozen_string_literal: true

require 'bundler/gem_tasks'
task default: :spec

desc 'Generate Docs'
task :docs do
  sh 'bundle', 'exec', 'yard', 'doc', '--fail-on-warning', '--output-dir', 'docs/'
end
