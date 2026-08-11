ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].each { |archivo| require archivo }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Constructor de escenarios académicos completos — ver test/support/.
  include EscenarioAcademico

  teardown { Current.reset }
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
