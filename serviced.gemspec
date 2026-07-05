# frozen_string_literal: true

require_relative "lib/serviced/version"

Gem::Specification.new do |spec|
  spec.name = "serviced"
  spec.version = Serviced::VERSION
  spec.authors = ["Leonardo Bernardelli"]
  spec.email = ["leobernardelli@gmail.com"]

  spec.summary = "Typed, immutable service objects with Success/Failure results and composable flows."
  spec.description = <<~DESC
    Serviced is a small framework for building service objects. Inputs are
    declared as typed, immutable attributes (backed by ActiveModel), can be
    validated with the ActiveModel validation DSL, and every call returns an
    explicit Success or Failure result. Services compose into flows that run
    with or without a database transaction.
  DESC
  spec.homepage = "https://github.com/lbernardelli/serviced"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob(%w[lib/**/*.rb README.md CHANGELOG.md LICENSE.txt])
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel", ">= 7.0", "< 9.0"
end
