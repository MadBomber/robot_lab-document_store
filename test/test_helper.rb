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
require 'minitest/reporters'

# rubocop:disable Style/FileOpen, Style/GlobalStdStream, Layout/LineLength
$stdout = File.open('test_output.txt', 'w').tap { |f| f.sync = true }

class TerminalSummaryReporter < Minitest::Reporters::BaseReporter
  def report
    super
    ok    = failures.zero? && errors.zero?
    badge = ok ? "\e[32mPASS\e[0m" : "\e[31mFAIL\e[0m"
    STDOUT.puts "[#{badge}] #{count} tests, #{failures} failures, #{errors} errors, #{skips} skips (#{format('%.2f', total_time)}s) — see test_output.txt"
    STDOUT.flush
  end
end
# rubocop:enable Style/FileOpen, Style/GlobalStdStream, Layout/LineLength

Minitest::Reporters.use! [
  Minitest::Reporters::DefaultReporter.new(color: false, slow_count: 5),
  TerminalSummaryReporter.new
]
