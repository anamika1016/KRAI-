require "test_helper"

# Office masters drift: an FCO-C or TO can be renamed, deactivated or mapped
# under a different category after a Jeevika Jankar was saved against it. The
# edit form must still offer the value the record actually holds, otherwise the
# dropdown silently shows a different office and saving overwrites the record.
class VrpEditKeepsSavedOfficeTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(first_name: "Office", last_name: "Admin", user_name: "office_edit_admin",
      email: "office-edit@example.test", mobile_no: "9876500401", password: "secret",
      user_type: "admin", status: "Active")

    # Masters know about Sausar only -- Pavijetpur is missing, the state the
    # Edit Jeevika Jankar screen was reported in.
    ModuleRecord.create!(module_slug: "office-mapping-add", data: {
      "office_category" => "FCO-C Sausar", "sub_office_name" => "TO-Sausar"
    })

    @vrp = Vrp.new(name: "Rathva Ramanbhai", father_husband_name: "vichhiyabhai", gender: :male,
      date_of_birth: Date.new(1977, 1, 6), date_of_joining: Date.current,
      aadhar_no: "950671848449", account_no: "30785013150", branch: "Pavijetpur Gujrat",
      ifsc_code: "SBIN0000561", address: "Pavijetpur", mobile_no: "8980976162",
      email: "rramanbhai737@example.test", experience_in_years: 3,
      office_detail_id: 0, to_office_detail_id: 0,
      fcoc: "FCO-C Pavijetpur", to_name: "TO-Pavijetpur")
    @vrp.save!(validate: false)
  end

  test "the edit form offers the FCO-C the record is actually saved against" do
    values = option_values(edit_assigns[:fcoc])

    assert_includes values, "FCO-C Pavijetpur", "saved FCO-C disappeared from the dropdown"
    assert_includes values, "FCO-C Sausar", "mapped offices must still be offered"
  end

  test "the edit form offers the TO the record is actually saved against" do
    assert_includes option_values(edit_assigns[:to]), "TO-Pavijetpur", "saved TO disappeared from the dropdown"
  end

  test "a record whose office is still mapped gains no duplicate entry" do
    @vrp.update_columns(fcoc: "FCO-C Sausar", to_name: "TO-Sausar")
    assigns = edit_assigns

    assert_equal 1, option_values(assigns[:fcoc]).count("FCO-C Sausar")
    assert_equal 1, option_values(assigns[:to]).count("TO-Sausar")
  end

  private

  def option_values(options)
    Array(options).map { |option| Array(option).last.to_s }
  end

  def edit_assigns
    controller = VrpsController.new
    controller.params = ActionController::Parameters.new(id: @vrp.id)
    payload = { "id" => @admin.id, "username" => @admin.user_name, "name" => @admin.full_name,
                "email" => @admin.email, "user_type" => "admin", "record_type" => "User" }
    controller.define_singleton_method(:current_app_user) { payload }
    controller.define_singleton_method(:redirect_to) { |*_args| nil }
    controller.send(:set_edit_dependencies)
    {
      fcoc: controller.instance_variable_get(:@fcoc_options),
      to: controller.instance_variable_get(:@to_options)
    }
  end
end
