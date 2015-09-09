require 'test_helper'

class McControllerTest < ActionController::TestCase
  test "should get journey" do
    get :journey
    assert_response :success
  end

end
