# frozen_string_literal: true

require_relative 'lib/robot_lab/document_store/version'

Gem::Specification.new do |spec|
  spec.name     = 'robot_lab-document_store'
  spec.version  = RobotLab::DocumentStore::VERSION
  spec.authors  = ['Dewayne VanHoozer']
  spec.email    = ['dvanhoozer@gmail.com']

  spec.summary     = 'Embedding-based semantic document store for RobotLab agents'
  spec.description = 'Provides RobotLab::DocumentStore — a thread-safe, in-memory semantic ' \
                     'search store backed by fastembed (BAAI/bge-small-en-v1.5). Store text ' \
                     'documents by key and retrieve the closest matches to a natural-language ' \
                     'query using cosine similarity. Works standalone or as a drop-in extension ' \
                     'for robot_lab agents and networks.'
  spec.homepage = 'https://github.com/madbomber/robot_lab-document_store'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 3.2.0'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ sig/])
    end
  end

  spec.require_paths = ['lib']

  spec.add_dependency 'fastembed'
end
