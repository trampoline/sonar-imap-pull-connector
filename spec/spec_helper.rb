$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'sonar_imap_pull_connector'
require 'spec'
require 'spec/autorun'
require 'rr'

Spec::Runner.configure do |config|
  config.mock_with RR::Adapters::Rspec
end
