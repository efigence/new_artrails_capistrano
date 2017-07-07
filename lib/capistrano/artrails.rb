# frozen_string_literal: true

load File.expand_path('../tasks/artrails.rake', __FILE__)

require 'capistrano/scm/plugin'

# By convention, Capistrano plugins are placed in the
# Capistrano namespace. This is completely optional.
class Capistrano::Artrails < ::Capistrano::Plugin
end
