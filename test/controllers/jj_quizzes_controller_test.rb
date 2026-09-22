require "test_helper"
require "rexml/document"
require "stringio"
require "zip"

class JjQuizzesControllerTest < ActionDispatch::IntegrationTest
  test "index does not expose direct exam login shortcut" do
    admin = create_admin_user
    create_quiz(title: "Hidden Login Shortcut Check")

    post login_path, params: { login: admin.user_name, password: "secret" }
    get jj_quizzes_path

    assert_response :success
    assert_not_includes response.body, "JJ Exam Login"
    assert_not_includes response.body, jj_exam_login_path
  end

  test "show renders admin QR sharing actions" do
    admin = create_admin_user
    quiz = create_quiz(title: "Shareable JJ Exam")
    create_question(quiz)

    post login_path, params: { login: admin.user_name, password: "secret" }
    get jj_quiz_path(quiz)

    assert_response :success
    assert_includes response.body, "Share Exam QR"
    assert_includes response.body, "Copy QR"
    assert_includes response.body, "Share Link on WhatsApp"
    assert_includes response.body, start_jj_exam_url(quiz)
  end

  test "show renders direct link and qr for scheduled exam without bypassing schedule" do
    admin = create_admin_user
    quiz = create_quiz(title: "Future JJ Exam", starts_at: 1.day.from_now, ends_at: 2.days.from_now)
    create_question(quiz)

    post login_path, params: { login: admin.user_name, password: "secret" }
    get jj_quiz_path(quiz)

    assert_response :success
    assert_includes response.body, "Share Exam QR / Link"
    assert_includes response.body, "Open Exam Link"
    assert_includes response.body, "Share Link on WhatsApp"
    assert_includes response.body, "Copy Link"
    assert_includes response.body, "Copy QR"
    assert_includes response.body, "Scheduled"
    assert_includes response.body, "This exam starts on"
    assert_not_includes response.body, "Activate Exam Now"
    assert_includes response.body, "jj-qr-svg"
    assert_includes response.body, start_jj_exam_url(quiz)
  end

  test "question format download only contains question columns" do
    admin = create_admin_user

    post login_path, params: { login: admin.user_name, password: "secret" }
    get question_template_jj_quizzes_path

    assert_response :success
    headers = xlsx_first_row(response.body)
    assert_equal ["Question", "Option A", "Option B", "Option C", "Option D", "Correct Option"], headers
    assert_not_includes headers, "Marks"
    assert_not_includes headers, "Position"
    assert_not_includes headers, "Status"
  end

  test "answer sheet export includes JJ selected answers" do
    admin = create_admin_user
    quiz = create_quiz(title: "Answer Export Exam")
    question = create_question(quiz, question_text: "Selected answer?", option_a: "No", option_b: "Yes", correct_option: "B")
    attempt = quiz.attempts.create!(vrp: create_vrp)
    attempt.grade!({ question.id.to_s => "B" })

    post login_path, params: { login: admin.user_name, password: "secret" }
    get export_answers_jj_quiz_path(quiz)

    assert_response :success
    rows = xlsx_rows(response.body)
    assert_includes rows.first, "Selected Answer"
    assert_includes rows.first, "Correct Answer"
    assert_equal "Answer Export Exam", rows.second[1]
    assert_equal "B", rows.second[16]
    assert_equal "B. Yes", rows.second[17]
    assert_equal "B. Yes", rows.second[19]
    assert_equal "Yes", rows.second[20]
  end

  test "admin can reset submitted attempt so JJ can take exam again" do
    admin = create_admin_user
    quiz = create_quiz(title: "Retake Reset Exam")
    question = create_question(quiz, question_text: "Retake question?", option_a: "No", option_b: "Yes", correct_option: "B")
    vrp = create_vrp(password: "secret")
    attempt = quiz.attempts.create!(vrp: vrp)
    attempt.grade!({ question.id.to_s => "B" })

    post login_path, params: { login: admin.user_name, password: "secret" }

    assert_difference -> { JjQuizAttempt.count }, -1 do
      assert_difference -> { JjQuizAnswer.count }, -1 do
        delete destroy_attempt_jj_quiz_path(quiz, attempt_id: attempt.id)
      end
    end
    assert_redirected_to results_jj_quiz_path(quiz)

    assert_difference -> { JjQuizAttempt.count }, 1 do
      post jj_exam_login_path, params: { jj_quiz_id: quiz.id, login: vrp.user_name, password: "secret" }
    end
    assert_redirected_to take_jj_exam_path(JjQuizAttempt.recent.first.access_token)
  end

  private

  def create_admin_user(attributes = {})
    User.create!({
      first_name: "Exam",
      last_name: "Admin",
      user_name: "exam_admin_#{SecureRandom.hex(3)}",
      email: "exam_admin_#{SecureRandom.hex(3)}@example.com",
      mobile_no: "9#{SecureRandom.random_number(10**9).to_s.rjust(9, "0")}",
      password: "secret",
      user_type: "admin",
      status: "Active"
    }.merge(attributes))
  end

  def create_quiz(attributes = {})
    JjQuiz.create!({
      title: "JJ Exam",
      duration_minutes: 30,
      status: "published"
    }.merge(attributes))
  end

  def create_question(quiz, attributes = {})
    quiz.questions.create!({
      question_text: "Question?",
      option_a: "A",
      option_b: "B",
      correct_option: "A",
      marks: 1,
      position: 1
    }.merge(attributes))
  end

  def create_vrp(attributes = {})
    Vrp.create!({
      name: "Export JJ",
      father_husband_name: "Test Father",
      gender: :male,
      date_of_birth: Date.new(1990, 1, 1),
      date_of_joining: Date.current,
      aadhar_no: "123456789012",
      account_no: "1234567890",
      bank_name: "Test Bank",
      branch: "Test Branch",
      ifsc_code: "TEST0123456",
      address: "Test Address",
      mobile_no: "9876543210",
      email: "jj_#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1,
      office_detail_id: 0,
      to_office_detail_id: 0,
      vrp_type_ids: [1],
      gram_panchayat_ids: [1],
      village_ids: [1],
      is_active: true,
      is_deleted: false,
      user_name: "jj_exam_#{SecureRandom.hex(4)}",
      password: "secret"
    }.merge(attributes))
  end

  def xlsx_first_row(body)
    xlsx_rows(body).first
  end

  def xlsx_rows(body)
    rows = []
    Zip::File.open_buffer(StringIO.new(body)) do |zip|
      sheet = REXML::Document.new(zip.read("xl/worksheets/sheet1.xml"))
      rows = REXML::XPath.match(sheet, "//*[local-name()='row']").map do |row|
        REXML::XPath.match(row, "*[local-name()='c']").map do |cell|
          REXML::XPath.match(cell, ".//*[local-name()='t']").map(&:text).join
        end
      end
    end
    rows
  end
end
