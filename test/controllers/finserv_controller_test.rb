require 'test_helper'

class FinservControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

end
