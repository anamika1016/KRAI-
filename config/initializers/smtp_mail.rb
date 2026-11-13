# Outgoing mail (used by the Jeevika Jankar payment update mail).
# These mails go out from the notification@ploughmanagro.com mailbox. Only the
# password must be supplied, through an environment variable; it is never
# stored in code.
#   SMTP_PASSWORD  password of notification@ploughmanagro.com   (required)
#   SMTP_ADDRESS   default smtp.gmail.com (ploughmanagro.com is on Google Workspace)
#   SMTP_PORT      default 587 (STARTTLS); 465 uses SSL
#   SMTP_USERNAME  default notification@ploughmanagro.com
#   MAIL_FROM      default SMTP_USERNAME
#   SMTP_AUTH      default "login"
# Without SMTP_PASSWORD the app keeps Rails' default delivery settings.
SMTP_DEFAULTS = {
  address: "smtp.gmail.com",
  port: "587",
  user_name: "notification@ploughmanagro.com"
}.freeze

if ENV["SMTP_PASSWORD"].present? && !Rails.env.test?
  port = ENV.fetch("SMTP_PORT", SMTP_DEFAULTS[:port]).to_i
  Rails.application.configure do
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"].presence || SMTP_DEFAULTS[:address],
      port: port,
      domain: ENV["SMTP_DOMAIN"].presence || "ploughmanagro.com",
      user_name: ENV["SMTP_USERNAME"].presence || SMTP_DEFAULTS[:user_name],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTH", "login").to_sym,
      ssl: port == 465,
      enable_starttls_auto: port != 465,
      open_timeout: 5,
      read_timeout: 10
    }
  end
end
