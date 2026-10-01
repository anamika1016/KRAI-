# Common answers do not need a provider round trip. Unknown questions fall
# through to AI; deliberately avoid interpreting arbitrary text as a DB query.
class AssistantQuickReply
  def initialize(context:, filters: {})
    @context = context
    @filters = filters
  end

  def call(messages)
    question = messages.last.fetch("content").strip
    if question.match?(/\b(excel|excle|xlsx|export|download)\b|एक्सेल/i)
      # "Export this" refers to the most recent user question, not AI prose.
      previous = messages[0...-1].reverse.find { |m| m["role"] == "user" }
      search = question
      search = "#{previous['content']} #{question}" if previous && question.match?(/\b(this|that|same|iska|isko|ye|bhi)\b/i)
      filters = AssistantReports.filters(search, @filters)
      downloads = AssistantReports.search(search, filters: filters)
      return { reply: downloads.any? ? "Excel ke liye report select karein. Download mein aapki existing access permissions apply hongi. Requested filters: #{filters.presence || 'report defaults'}. Module exports contain all visible records; report exports apply their supported filters." : "Kaunsa data Excel mein chahiye? Neeche Excel reports kholkar report search karein — farmers, training, bills, targets ya koi module.", downloads: downloads, show_reports: true }
    end

    return { reply: "Namaste! Main Jeevika Jankar app ke baare mein aapki madad kar sakta hoon. Aap kya jaanna chahte hain?" } if question.match?(/\A(hi|hello|hey|namaste|नमस्ते)[!. ]*\z/i)

    # Exact module title/slug + help gets a maintained, code-derived answer.
    help_query = question.downcase.sub(/\A(?:help|about|how to use)\s+/, "").sub(/\s+(?:kya hai|kaise use kare|help)\??\z/, "").delete_suffix("?").strip
    match = ModulesController::MODULES.find { |slug, m| [slug, slug.tr("-", " "), m[:title].downcase].include?(help_query) }
    if match
      slug, definition = match
      title = display_label(definition[:title])
      fields = Array(definition[:fields]).map { |field| display_label(field) }
      return { reply: "#{title}\n#{display_label(definition[:purpose])}\n\nFields: #{fields.join(', ')}", links: [{ title: "Open #{title}", url: "/modules/#{slug}" }] }
    end

    # Only a tightly bounded gender query can bypass the language model.
    if question.match?(/\A(?:(?:sausar|turekela|pavijetpur|1004|1006|1095|male|female|gender|jj|vrp|active|count|kitne|hai|hain|total|in|ke|ka|ki|and|aur|\s|[?.,])|(?:#{Date::MONTHNAMES.compact.join('|')}))+\z/i) && question.match?(/\b(male|female|gender)\b/i)
      data = @context.call(messages)
      return unless data[:jj_gender_by_fco]
      rows = data[:jj_gender_by_fco]
      fco = { "1004" => "sausar", "1006" => "turekela", "1095" => "pavijetpur" }.find { |id, name| question.match?(/\b(?:#{id}|#{name})\b/i) }&.last
      rows = rows.select { |row| row[:fco].downcase.include?(fco) } if fco
      # Asking for a "gender count" means both; naming one gender narrows to it.
      genders = %w[male female].select { |g| question.match?(/\b#{g}\b/i) }
      genders = %w[male female] if genders.empty?
      return { reply: "Is FCO ke visible JJ gender records nahi mile. FCO aur month check karein." } if rows.empty?
      text = rows.map { |row| "#{row[:fco]}: #{genders.map { |g| "#{g.capitalize} #{row[g.to_sym]}" }.join(', ')}" }.join("\n")
      return { reply: "Active JJ / VRP gender count — #{data[:month]}\n#{text}\nSirf aapke visible JJ records. Yeh farmer gender count nahi hai." }
    end

    if question.match?(/\A(?:(?:sausar|turekela|pavijetpur|1004|1006|1095|total|farmer|farmers|village|villages|ics|count|kitne|hai|hain|in|ke|ka|ki|\s|[?.,]))+\z/i)
      metric = if question.match?(/\b(farmer|farmers)\b/i) then :farmers
               elsif question.match?(/\b(village|villages)\b/i) then :villages
               elsif question.match?(/\bics\b/i) then :ics end
      if metric
        data = @context.call(messages)
        return { reply: "#{metric.to_s.capitalize}: #{data[metric]}\n#{data[:scope]}" } if data.key?(metric)
      end
    end

    return unless question.match?(/\A(?:dashboard |live |project )?summary\??\z/i)
    data = @context.call(messages)
    return unless data[:farmers]
    { reply: "Visible project summary\nFarmers: #{data[:farmers]}\nVillages: #{data[:villages]}\nICS: #{data[:ics]}\n#{display_label(data[:scope])}" }
  end

  private

  # Module definitions still use the original field names, but the screens show
  # renamed labels: resource_person_label covers the stored renames and the UI
  # additionally rewrites "activity" and "VRP" in the browser. Quoting the raw
  # names told users to look for fields that are not on the form, so the
  # assistant answers with exactly what is on screen.
  def display_label(text)
    ApplicationController.helpers.resource_person_label(text)
      .gsub(/\bactivities\b/i, "Major Work Indicators")
      .gsub(/\bactivity\b/i, "Major Work Indicator")
      .gsub(/\bvrps\b/i, "Jeevika Jankars")
      .gsub(/\bvrp\b/i, "Jeevika Jankar")
  end
end
