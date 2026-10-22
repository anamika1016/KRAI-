require "test_helper"

# Whatever is still waiting on somebody has to sit at the top of the list --
# that is the only part a reviewer has to act on.
class PendingRowsOnTopTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(user_name: "pending_top_admin", password: "secret", first_name: "Pending",
      last_name: "Top", user_type: "admin", status: "Active", email: "pending-top@example.test",
      mobile_no: "9876500922")
    post login_path, params: { login: "pending_top_admin", password: "secret" }
  end

  test "Jeevika Jankar List puts waiting rows above finished ones" do
    approved = create_jj("Zara Approved", status: 55)
    waiting = create_jj("Aaron Waiting", status: 10)

    get vrps_path
    assert_response :success

    labels = status_labels
    assert_equal %w[Submitted Final\ Approved], labels, "only the two seeded rows, waiting first"

    names = row_names
    assert_operator names.index(waiting.name), :<, names.index(approved.name),
      "the waiting JJ has to render above the approved one even though it sorts later by name"
  end

  test "Jeevika Jankar List keeps the order inside a bucket" do
    first = create_jj("First Waiting", status: 10)
    second = create_jj("Second Waiting", status: 10)

    get vrps_path
    assert_response :success

    names = row_names
    assert_operator names.index(first.name), :<, names.index(second.name)
  end

  test "Bill List puts pending and unsent bills above approved ones" do
    bill("Final Approved", "June")
    bill("Pending at Someone (Manager)", "June")
    bill("Submitted (Not sent for approval)", "June")

    get module_path("jeevika-jankar-bill-list"), params: { bill_month: "" }
    assert_response :success

    statuses = css_texts(".grid-status, td")
      .select { |text| text.match?(/Final Approved|Pending at|Not sent for approval/) }
    refute_empty statuses
    assert_equal "Final Approved", statuses.last, "approved bills sink to the bottom"
    refute_equal "Final Approved", statuses.first
  end

  private

  def status_labels
    css_texts(".grid-status")
  end

  # Columns: select, view, active, status, id, user name, name.
  def row_names
    css_texts("tbody tr td:nth-child(7)")
  end

  def css_texts(selector)
    Nokogiri::HTML(response.body).css(selector).map { |node| node.text.strip }.reject(&:blank?)
  end

  def create_jj(name, status:)
    Vrp.create!(name: name, father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "12345678901#{rand(0..9)}", account_no: "1234567890", bank_name: "Bank",
      branch: "Branch", ifsc_code: "TEST0123456", address: "Address", mobile_no: "9876543210",
      email: "jj_#{SecureRandom.hex(4)}@example.com", experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1], gram_panchayat_ids: [1],
      village_ids: [1], user_name: "jj_#{SecureRandom.hex(4)}", password: "secret", status: status)
  end

  def bill(status, month)
    ModuleRecord.create!(module_slug: "jeevika-jankar-bill-process", data: {
      "status" => status, "bill_month" => month, "jeevika_jankar_name" => "JJ #{SecureRandom.hex(3)}"
    })
  end
end
