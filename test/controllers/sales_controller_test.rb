require 'test_helper'

class SalesControllerTest < ActionController::TestCase
  test "should get leadlist" do
    get :leadlist
    assert_response :success
  end

end
