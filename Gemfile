# frozen_string_literal: true

source 'https://rubygems.org'

gem 'net-imap', '0.5.4'
gem 'rb-readline' # For bypassing the default readline input limit of 1024 chars

gem 'awesome_print' # Pretty data output
gem 'dotenv' # Local management of sensitive data
gem 'faraday'
gem 'httparty' # For manual HTTP calls

group :ai do
  gem 'anthropic'
  gem 'ruby-openai'
end

group :text do
  gem 'caracal'
  gem 'docx'
  gem 'nokogiri'
  gem 'pragmatic_segmenter'
  gem 'rubyzip', '~> 1.1', require: 'zip'
end

gem 'rubocop', group: 'development', require: false
