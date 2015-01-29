class PnrDataRequest
  include ActiveModel::Model
  attr_accessor :pnr, :gds, :remarks, :mails

  validates :pnr, :gds, presence: true
  validates :pnr, length: { is: 6 }
  validates :gds, inclusion: { in: %w(Sabre Amadeus), message: "%{value} is not a valid gds" }

  def sabre?
  	self.gds == "Sabre"
  end

  def amadeus?
  	self.gds == "Amadeus"
  end

end