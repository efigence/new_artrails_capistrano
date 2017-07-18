# Capistrano [![Gem Version](https://badge.fury.io/rb/new_artrails_capistrano.svg)](https://badge.fury.io/rb/new_artrails_capistrano) [![Build Status](https://travis-ci.org/efigence/new_artrails_capistrano.svg?branch=master)](https://travis-ci.org/efigence/new_artrails_capistrano) [![Coverage Status](https://coveralls.io/repos/github/efigence/new_artrails_capistrano/badge.svg?branch=master)](https://coveralls.io/github/efigence/new_artrails_capistrano?branch=master)

Capistrano 3 deployment using Rsync, a local Git repository and sudo as user.

This gem is a viable alternative to Git deployments on production machines. Commands can be run under a different user than the `deploy` user.

## Installation

```
$ echo '2.1.1' > .ruby-version
$ rvm use
```

Add this line to your application's Gemfile:

```ruby
gem 'new_artrails_capistrano'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install new_artrails_capistrano

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

```
$ guard #  require './lib/new_artrails_capistrano'
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/efigence/new_artrails_capistrano. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
