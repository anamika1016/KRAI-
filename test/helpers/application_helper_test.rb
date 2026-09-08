require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper

  test "favicon uses the same saved stakeholder logo as the sidebar" do
    record = ModuleRecord.new(data: { "logo_upload" => "/uploads/stakeholder-logo.png" })
    define_singleton_method(:matching_stakeholder_record) { |slug| slug == "stakeholder-master" ? record : nil }
    assert_equal "/uploads/stakeholder-logo.png", app_stakeholder_logo
    assert_equal app_stakeholder_logo, app_logo_path
  end

  test "Jeevika Jankar bill menu permissions do not grant later payment menus" do
    bill_list_keys = sidebar_access_name_keys("Bill List")
    payment_list_keys = sidebar_access_name_keys("Payment List")
    payment_detail_keys = sidebar_access_name_keys("Payment List Detail")

    assert_includes bill_list_keys, "jeevika-jankar-bill-list"
    assert_not_includes bill_list_keys, "jeevika-jankar-payment-list"
    assert_not_includes bill_list_keys, "jeevika-jankar-completed-payment-list"

    assert_includes payment_list_keys, "jeevika-jankar-payment-list"
    assert_not_includes payment_list_keys, "jeevika-jankar-payment-list-detail"
    assert_not_includes payment_list_keys, "jeevika-jankar-completed-payment-list"

    assert_includes payment_detail_keys, "jeevika-jankar-payment-list-detail"
    assert_not_includes payment_detail_keys, "jeevika-jankar-completed-payment-list"
  end
end
