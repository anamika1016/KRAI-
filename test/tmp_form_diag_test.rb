require "test_helper"

class TmpFormDiagTest < ActionDispatch::IntegrationTest
  test "dump required fields on training form for a VRP login" do
    vrp = Vrp.create!(
      name: "Diag VRP", user_name: "diag_vrp", father_husband_name: "F", gender: :male,
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current,
      aadhar_no: "123456789099", account_no: "1234567890", bank_name: "B", branch: "Br",
      ifsc_code: "TEST0123456", address: "A", mobile_no: "9876543299",
      email: "diag#{SecureRandom.hex(4)}@example.com", experience_in_years: 1,
      office_detail_id: 0, to_office_detail_id: 0, vrp_type_ids: [1],
      gram_panchayat_ids: [1], village_ids: [1], is_active: true, is_deleted: false,
      agreement_accepted_at: Time.current, password: "secret"
    )

    post login_path, params: { login: vrp.user_name, password: "secret" }
    follow_redirect!
    get module_path("training-form")
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    form = doc.at_css("#module-form") || doc.at_css("form")

    puts "\n===== REQUIRED CONTROLS ON TRAINING FORM ====="
    form.css("[required]").each do |el|
      name = el["name"]
      tag = el.name
      readonly = el["readonly"] ? " READONLY" : ""
      disabled = el["disabled"] ? " DISABLED" : ""
      hidden_attr = el["hidden"] ? " HIDDEN-ATTR" : ""
      style = el["style"].to_s
      inline_hidden = style.include?("display:none") || style.include?("display: none") ? " INLINE-DISPLAY-NONE" : ""

      value =
        if tag == "select"
          sel = el.css("option[selected]").map { |o| o["value"] }.reject(&:blank?)
          "selected=#{sel.inspect}"
        elsif tag == "textarea"
          "text=#{el.text.strip.inspect}"
        else
          "value=#{el["value"].inspect} type=#{el["type"].inspect}"
        end

      # Walk ancestors looking for a container hidden inline.
      hidden_ancestor = ""
      el.ancestors.each do |a|
        next unless a.respond_to?(:[])
        st = a["style"].to_s
        if st.include?("display:none") || st.include?("display: none") || a["hidden"]
          hidden_ancestor = " HIDDEN-ANCESTOR<#{a.name}.#{a['class']}>"
          break
        end
      end

      empty =
        if tag == "select"
          el.css("option[selected]").map { |o| o["value"] }.reject(&:blank?).empty?
        elsif tag == "textarea"
          el.text.strip.empty?
        else
          el["value"].to_s.strip.empty?
        end

      flag = empty ? "  <<< EMPTY" : ""
      puts "#{tag.ljust(8)} #{name.to_s.ljust(42)} #{value}#{readonly}#{disabled}#{hidden_attr}#{inline_hidden}#{hidden_ancestor}#{flag}"
    end

    puts "\n===== EMPTY + REQUIRED + NOT readonly/disabled (these block submit) ====="
    blockers = form.css("[required]").reject { |el| el["readonly"] || el["disabled"] }.select do |el|
      if el.name == "select"
        el.css("option[selected]").map { |o| o["value"] }.reject(&:blank?).empty?
      elsif el.name == "textarea"
        el.text.strip.empty?
      else
        el["value"].to_s.strip.empty?
      end
    end
    blockers.each { |el| puts "BLOCKER: <#{el.name}> name=#{el['name'].inspect} type=#{el['type'].inspect}" }
    puts "(total blockers: #{blockers.size})"
    puts "=====\n"
  end
end
