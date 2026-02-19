require "test_helper"

class DemoRequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get demo_requests_new_url
    assert_response :success
  end

  test "should get create" do
    get demo_requests_create_url
    assert_response :success
  end
end
