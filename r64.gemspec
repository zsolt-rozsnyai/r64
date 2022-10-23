# frozen_string_literal: true

require_relative "lib/r64/version"

Gem::Specification.new do |spec|
  spec.name = "r64"
  spec.version = R64::VERSION
  spec.authors = ["Maxwell of Graffity"]
  spec.email = [""]

  spec.summary = "Ruby Commodore 64 Assembler"
  spec.description = "A Ruby-based assembler for Commodore 64 development with debugging capabilities"
  spec.homepage = "https://github.com/example/r64"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/example/r64"
  spec.metadata["changelog_uri"] = "https://github.com/example/r64/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir.glob("{lib,bin}/**/*", File::FNM_DOTMATCH).reject do |f|
      File.directory?(f) || f.include?("debugger")
    end + %w[r64.gemspec Gemfile README.md]
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "chunky_png", "~> 1.4"
  spec.add_dependency "dry-cli", "~> 1.4"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.0"
end
