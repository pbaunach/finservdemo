require 'test_helper'

class InsControllerTest < ActionController::TestCase
  test "should get community" do
    get :community
    assert_response :success
  end

end
