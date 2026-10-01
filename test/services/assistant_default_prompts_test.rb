require "test_helper"

# The three suggestion buttons on the assistant welcome screen are the first
# thing every user clicks, so each one must return a correct, self-consistent
# answer without falling through to the language model.
class AssistantDefaultPromptsTest < ActiveSupport::TestCase
  # Kept in step with the buttons in app/views/shared/_assistant.html.erb.
  PROMPTS = {
    "Project summary" => "Project summary",
    "Sausar JJ gender count" => "Sausar JJ gender count",
    "Training form help" => "Training form kya hai"
  }.freeze

  setup do
    @user = User.create!(first_name: "Ask", last_name: "Ai", user_name: "assistant_default_user",
      email: "assistant-default@example.test", mobile_no: "9876500601", password: "secret",
      user_type: "admin", status: "Active")
    @vrp = Vrp.new(name: "Gender JJ", father_husband_name: "Father", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789012", account_no: "1234", branch: "Test", ifsc_code: "TEST0123456",
      address: "Test", mobile_no: "9876500602", email: "gender-jj@example.test", fcoc: "Sausar",
      experience_in_years: 1, office_detail_id: 0, to_office_detail_id: 0)
    @vrp.save!(validate: false)
    Afl.create!(farmer_name: "Summary Farmer", tracenet_no: "summary-farmer", fco_id: "1004",
      fco: "Sausar", ics_id: "summary-ics", ics_name: "Summary ICS",
      village_id: "summary-village", village_name: "Summary Village")
  end

  test "every suggestion button is answered without falling through to AI" do
    PROMPTS.each do |label, prompt|
      assert reply(prompt), "\"#{label}\" button produced no direct answer"
    end
  end

  test "the gender button reports both genders, not only male" do
    text = reply(PROMPTS.fetch("Sausar JJ gender count")).fetch(:reply)

    assert_match(/Male \d+/, text)
    assert_match(/Female \d+/, text, "button says gender count but the answer omitted Female")
  end

  test "the training form button uses the labels shown on the form" do
    text = reply(PROMPTS.fetch("Training form help")).fetch(:reply)

    assert_match(/Main Major Work Indicator/, text)
    assert_match(/ICS Name/, text)
    assert_match(/Village Name/, text)
    refute_match(/ICS \/ Block/, text, "internal field name leaked into the answer")
    refute_match(/Gram Name/, text, "internal field name leaked into the answer")
    refute_match(/\bVRP\b/, text, "VRP wording leaked into the answer")
  end

  test "the project summary button reports visible totals" do
    text = reply(PROMPTS.fetch("Project summary")).fetch(:reply)

    assert_match(/Farmers: 1/, text)
    assert_match(/Villages: 1/, text)
    assert_match(/ICS: 1/, text)
  end

  test "project summary totals equal the dashboard summary cards" do
    # A farmer outside the project FCOs, and one with no tracenet number. The
    # dashboard cards exclude both; the assistant must exclude them too.
    Afl.create!(farmer_name: "Other FCO Farmer", tracenet_no: "other-fco", fco_id: "9999",
      fco: "Elsewhere", ics_id: "other-ics", ics_name: "Other ICS",
      village_id: "other-village", village_name: "Other Village")
    Afl.create!(farmer_name: "No Tracenet Farmer", tracenet_no: "", fco_id: "1004",
      fco: "Sausar", ics_id: "summary-ics", ics_name: "Summary ICS",
      village_id: "summary-village", village_name: "Summary Village")

    text = reply(PROMPTS.fetch("Project summary")).fetch(:reply)
    cards = dashboard_card_counts

    assert_equal cards[:farmers], text[/Farmers: (\d+)/, 1].to_i, "farmer total disagrees with the dashboard card"
    assert_equal cards[:villages], text[/Villages: (\d+)/, 1].to_i, "village total disagrees with the dashboard card"
    assert_equal cards[:ics], text[/ICS: (\d+)/, 1].to_i, "ICS total disagrees with the dashboard card"
  end

  private

  def dashboard_card_counts
    policy = ModulesController.new
    policy.request = ActionDispatch::TestRequest.create
    policy.params = ActionController::Parameters.new(month: DashboardDefaults.month)
    policy.define_singleton_method(:current_app_user) { { "user_type" => "admin" } }
    {
      farmers: policy.send(:dashboard_total_afl_farmer_count),
      villages: policy.send(:dashboard_total_afl_village_count),
      ics: policy.send(:dashboard_total_afl_ics_count)
    }
  end

  def reply(prompt)
    controller = AssistantController.new
    controller.set_request!(ActionDispatch::TestRequest.create)
    user = @user
    payload = { "id" => user.id, "username" => user.user_name, "name" => user.full_name,
                "email" => user.email, "user_type" => "admin", "record_type" => "User" }
    controller.define_singleton_method(:current_app_user) { payload }
    context = AssistantContext.new(controller)
    AssistantQuickReply.new(context: context).call([{ "role" => "user", "content" => prompt }])
  end
end
