class JjQuizAnswer < ApplicationRecord
  belongs_to :attempt, class_name: "JjQuizAttempt", foreign_key: :jj_quiz_attempt_id
  belongs_to :question, class_name: "JjQuizQuestion", foreign_key: :jj_quiz_question_id

  def question_text
    snapshot_value("question_text").presence || question&.question_text.to_s
  end

  def question_position
    snapshot_value("position").presence || question&.position
  end

  def question_marks
    snapshot_value("marks").presence || question&.marks
  end

  def option_text(option)
    option = option.to_s.downcase
    return if option.blank?

    snapshot_value("option_#{option}").presence || question&.option_label(option.upcase)
  end

  def selected_option_text
    option_text(selected_option)
  end

  def correct_option_text
    option_text(correct_option)
  end

  def selected_answer_label
    selected_option.present? ? "#{selected_option}. #{selected_option_text.presence || "-"}" : "Skipped"
  end

  def correct_answer_label
    "#{correct_option}. #{correct_option_text.presence || "-"}"
  end

  private

  def snapshot_value(key)
    question_snapshot.to_h[key.to_s]
  end
end
