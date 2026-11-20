class AppLoginEvent < ApplicationRecord
  validates :account_type, :logged_in_at, presence: true

  scope :on_date, ->(date) { where(logged_in_at: date.all_day) }
  scope :in_month, ->(date) { where(logged_in_at: date.all_month) }
  scope :newest_first, -> { order(logged_in_at: :desc, id: :desc) }

  PERIODS = %w[day month all].freeze

  # The list and its export read the same window, so they can never disagree.
  def self.for_period(period, date)
    case period
    when "month" then in_month(date)
    when "all" then all
    else on_date(date)
    end
  end

  # Record one successful app login. Never let bookkeeping break a login: a
  # failure here is logged and swallowed so the user still gets their token.
  def self.record!(user, at: Time.current)
    return nil unless user

    create!(
      account_type: user.class.name,
      account_id: user.id,
      user_name: user.try(:user_name),
      display_name: display_name_for(user),
      role: role_for(user),
      logged_in_at: at
    )
  rescue StandardError => e
    Rails.logger.warn("App login not recorded: #{e.class} - #{e.message}")
    nil
  end

  def self.display_name_for(user)
    return user.name if user.respond_to?(:name) && user.name.present?

    [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ").presence ||
      user.try(:user_name)
  end

  # A Jeevika Jankar has no role column of its own; its type is the role the
  # rest of the app shows for it.
  def self.role_for(user)
    return user.role if user.respond_to?(:role) && user.role.present?
    return "Jeevika Jankar" if user.is_a?(Vrp)

    user.try(:stakeholder_role).presence || user.try(:user_type)
  end
end
