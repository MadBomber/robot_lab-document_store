# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'

  add_group 'DocumentStore', 'lib/robot_lab/document_store'

  enable_coverage :branch
  minimum_coverage line: 95, branch: 75
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'robot_lab/document_store'

require 'minitest/autorun'
require 'minitest/pride'
