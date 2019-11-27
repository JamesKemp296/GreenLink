class FplAccount < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :user
  has_many :bills, dependent: :destroy
  has_many :syncs, dependent: :destroy
  has_many :account_challenges, dependent: :destroy
  has_many :challenges, through: :account_challenges

  include Encryptable
  attr_encrypted :username, :password

  default_scope { includes(user: :profile) }

  scope :testing,         -> { where(zipcode: "33024" )}

  def scrape_for_bills
    BillScrapeJob.perform_later(self)
  end

  def as_json(options={})
    {
      id:                 id,
      zipcode:            zipcode,
      user_email:         user.email,
      points:             user.points,
      avatar:             user.profile&.avatar ? url_for(user.profile.avatar) : 'https://i.pravatar.cc/300'
    }
  end
end
