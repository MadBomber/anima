# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in anima-core.gemspec
gemspec  #

group :development, :test do
  gem "aigcm"     # AI-powered git commit message generator
  gem "debug_me"  # A tool to print the labeled value of variables.
  gem "irb"       # Interactive Ruby command-line tool for REPL (Read Eval Print Loop).
  gem "rake"      # Rake is a Make-like program implemented in Ruby
  gem "reek"      # Code smell detector for Ruby
  gem "standard"  # Ruby Style Guide, with linter & automatic code fixer
end

group :test do
  gem "simplecov", require: false  # Code coverage for Ruby
  gem "webrick"                    # HTTP server toolkit
end
