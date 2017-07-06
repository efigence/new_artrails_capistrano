# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Capistrano do
  it 'has a version number' do
    expect(NewArtrailsCapistrano::VERSION).not_to be nil
  end
end
