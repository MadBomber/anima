# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in anima-core.gemspec
gemspec

gem "irb"
gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"
gem "rspec-rails", "~> 7.0"

gem "reek", "~> 6.5"
gem "standard", "~> 1.3"

gem "webmock", "~> 3.23"

group :development, :test do
  gem 'debug_me'
  gem 'aigcm'
end

group :test do
  gem 'simplecov', require: false
  gem 'webrick'
end
