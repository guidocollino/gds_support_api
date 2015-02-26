require "amadeus_ws_support"
require "sabre_ws_support"

module GdsWsSupport

	SABRE = "Sabre"
  	AMADEUS = "Amadeus"

    #devuelve una hash con la cantidad de pax, el printer para mostrar los datos y un status
	def self.get_data(pnr_code, gds)
  
		response = Hash.new
		printer = nil
		cant_pax = 0
		status = "ERROR"
		if gds == GdsWsSupport::SABRE then
		    pnr_info = SabreWsSupport.get_pnr_info(pnr_code)
		    unless pnr_info.nil?
	    		printer = SabreWsSupport::PnrHtmlPrinter.new(pnr_info) 
	    		cant_pax = pnr_info.cant_pax
	    		status = "OK"
	    	end
		elsif gds == GdsWsSupport::AMADEUS
		  	pnr_info = AmadeusWsSupport.get_pnr_info(pnr_code)
		   	unless pnr_info.nil?
	    		printer = AmadeusWsSupport::PnrHtmlPrinter.new(pnr_info) 
	    		cant_pax = pnr_info.cant_pax
	    		status = "OK"
	    	end
	    else
	    	status = "invalid gds"
		end

		response["cant_pax"] = cant_pax
		response["printer"] = printer
		response["status"] = status
		return response
	end

	#devuelve una hash con la cantidad de pax, el printer para mostrar los datos y un status
	def self.send_itinerary(pnr_code, gds, emails)
		#response = Hash.new
		response = "ERROR"
		if gds == GdsWsSupport::SABRE then
		    response = SabreWsSupport.send_itinerary(pnr_code,emails)
		elsif GdsWsSupport::AMADEUS
			response = AmadeusWsSupport.send_itinerary(pnr_code,emails)
	    else
	    	response = "invalid gds"
		end
		#response["status"] = status
		return response
	end
end