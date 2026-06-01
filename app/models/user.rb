class User < ApplicationRecord
  validates :user_name, presence: true
  validates :password, presence: true

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end

  def active?
    status.blank? || status == "Active"
  end
end
