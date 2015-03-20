source 'https://rubygems.org'

gem 'berkshelf',  '~> 3.1.3'
gem 'chefspec',   '~> 4.0'
# gem 'foodcritic', '~> 3.0'
gem 'rake',       '~> 10.1'
gem 'rubocop',    '~> 0.24.0'
gem 'chef',       '< 12' if RUBY_VERSION.to_f < 2.0

group :integration do
    gem 'test-kitchen',    '~> 1.2'
    gem 'kitchen-vagrant', '~> 0.14'
end
