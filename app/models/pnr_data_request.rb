class PnrDataRequest
  include ActiveModel::Model
  attr_accessor :pnr, :gds, :remarks

  validates :pnr, :gds, presence: true
  validates :pnr, length: { is: 6 }
  validates :gds, inclusion: { in: %w(Sabre Amadeus), message: "%{value} is not a valid gds" }

end