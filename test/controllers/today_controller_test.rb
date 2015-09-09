require 'test_helper'

class TodayControllerTest < ActionController::TestCase
  test "should get today" do
    get :today
    assert_response :success
  end

end
