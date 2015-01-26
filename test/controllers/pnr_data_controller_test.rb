require 'test_helper'

class PnrDataControllerTest < ActionController::TestCase
  test "should get get_pnr_info_form_gds" do
    get :get_pnr_info_form_gds
    assert_response :success
  end

end
