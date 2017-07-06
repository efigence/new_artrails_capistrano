# frozen_string_literal: true

require_relative 'env'
require_relative 'lib/capistrano/artrails.rb'

artrails = Capistrano::Artrails.new(ARGV.first)
result = artrails.perform
puts result
exit 1 if result != 'ok'
