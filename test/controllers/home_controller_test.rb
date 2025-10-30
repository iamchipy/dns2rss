require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders successfully" do
    get root_path
    assert_response :success
    assert_select "h1", "dns2rss"
  end
end
