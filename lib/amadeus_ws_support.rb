require "aptek_tkt_web_services"

module AmadeusWsSupport
	###############SEND ITINERARY########################

	def self.send_itinerary(pnr_code,emails)
		response = "ERROR"

		for email in emails
			response = AptekTktWebServices::Services.send_itinerary(pnr_code,email)
		end

		return response

	end

	###############GET PNR DATA########################


	def self.get_pnr_info(pnr_code)
		pnr_json = AptekTktWebServices::Services.get_pnr(pnr_code,"Amadeus")
		unless pnr_json.nil?
			return PnrInfoWrapper.new(pnr_code, pnr_json)
		end
		return nil
	end

	class ParserDate

		attr_accessor :origin_datetime

		def initialize(date_number, year = false)
			if year then
				self.origin_datetime = DateTime.strptime(date_number, '%d%m%y%H%M')
			else
				self.origin_datetime = DateTime.strptime(date_number, '%m-%dT%H:%M')
	      	end
	    end

	    def get_amadeus_date
	    	return origin_datetime.strftime("%d%^b")
	    end

	    def get_amadeus_date_with_year
	    	return origin_datetime.strftime("%d%^b%y")
	    end

	    def get_amadeus_time
	    	return origin_datetime.strftime("%H%M")
	    end


	end

	class TotalsData
		attr_accessor :pnr_info, :fares, :base_fare, :equiv_fare, :taxes, :total

		def initialize(pnr_info)
			self.pnr_info = pnr_info
			self.fares = pnr_info.fares_data
		    self.base_fare = 0
			self.equiv_fare = 0
			self.taxes = 0
			self.total = 0
			calculate
	    end


	    def calculate
	    	fares_objects = []
	    	if self.fares.is_a?(Array) then 
		    	self.fares.each {	|f|	fares_objects.push(FareData.new(f,self.pnr_info)) }
		    else
		    	fares_objects.push(FareData.new(self.fares,self.pnr_info))
		    end 
		    fares_objects.each {	
		    	|fare_object|
		    	cant_pax = fare_object.cant_pax_associated
			    self.base_fare += (fare_object.fare_base["amount"].to_f)*cant_pax unless fare_object.fare_base.nil?
			    self.equiv_fare += (fare_object.fare_equiv["amount"].to_f)*cant_pax unless fare_object.fare_equiv.nil?
			    #self.taxes += totals[:taxes][:tax][:@amount].to_f
			    self.total += (fare_object.fare_total["amount"].to_f)*cant_pax unless fare_object.fare_total.nil?
			}
	    end

	    def text_base_fare
	    	return (base_fare == 0) ? '' : '%.2f' % base_fare
	    end

	    def text_equiv_fare
	    	return (equiv_fare == 0) ? '' : '%.2f' % equiv_fare
	    end

	    def text_taxes
	    	return (taxes == 0) ? '' : '%.2f' % taxes
	    end

	    def text_total
	    	return (total == 0) ? '' : '%.2f' % total
	    end

	    def line_totals
	    	response = "<p>TOTALES</p>"
	    	response += "<table>"\
		    		"<tr>"\
	    			"<td>PAXS</td>"\
	    			"<td>TOTAL</td>"\
	  				"</tr>"
	    	response += "<tr>"

	    	response += "<td>#{pnr_info.cant_pax}</td>"
	    	response += "<td>#{text_total}</td>"
	    	response += "</tr>"
	    	response += "</table>"
	    	return response
	    end
	end

	class FareData
		attr_accessor :fare_element, :pnr_info, :printer, :total_base_fare, :total_equiv_fare, :total_taxes, :total

		def initialize(fare_element, pnr_info)
			self.fare_element = fare_element
			self.pnr_info = pnr_info
			self.printer = PnrPrinter.new(pnr_info)
	    end

	    #GETTERS

	    def fare_base
	    	result =  nil
	    	fares = fare_element["fareData"]["monetaryInfo"].select { |f| f["qualifier"] == "F"	}
	    	result = fares[0] unless fares.empty?
	    	return result
	    end

	    def fare_equiv
	    	result =  nil
	    	fares = fare_element["fareData"]["monetaryInfo"].select { |f| f["qualifier"] == "E"	}
	    	result = fares[0] unless fares.empty?
	    	return result
	    end

	    def fare_total
	    	result =  nil
	    	fares = fare_element["fareData"]["monetaryInfo"].select { |f| f["qualifier"] == "T"	}
	    	result = fares[0] unless fares.empty?
	    	return result
	    end

	    #FIN GETTERS

	    def fare_base_text
	    	fb = self.fare_base
	    	return "FARE #{fare_element["fareData"]["issueIdentifier"]} #{fb["currencyCode"]} #{fb["amount"]}"
	    end

	    def fare_equiv_text
	    	fe = self.fare_equiv
	    	
	    	if fe.nil?
	    		return ""
	    	else
	    		return "EQUIV  #{fe["currencyCode"]} #{fe["amount"]}"
	    	end
	    end

	    def fare_total_text
	    	ft = self.fare_total
	    	if ft.nil?
	    		return ""
	    	else
	    		return "TOTAL  #{ft["currencyCode"]} #{ft["amount"]}"
	    	end
	    end

	    def taxes_tables
	    	taxes = fare_element["fareData"]["taxFields"]
	    	unless taxes.blank?
		    	table = "<table>"
				div_taxes = taxes.each_slice(4).to_a
		    	div_taxes.each {
		    		|ts|
		    		table += "<tr>"
		    		 ts.each { 
		    		 	|t|  
			    		table += "<td>#{t['taxCurrency']} #{t['taxAmount']}#{t['taxCountryCode']} #{t['taxNatureCode']}</td>"
			    	}
		    		table += "</tr>"
		    	}

		    	table += "</table>"
		    	return 	table
		    else
		    	return ""
		    end
	    end

	    def fare_paxs
	    	response = ""
	    	associated_passengers.each {
	    		|pax|
	    		 response += "#{printer.unique_pax(pax)} "
	    	}
	    	return response
	    end

	    def cant_pax_associated
	    	return associated_passengers.size
	    end

	    private

	    def associated_passengers
	    	paxs = []
	    	pax_reference = fare_element["referenceForTstData"]["reference"].select {
	    		|f|
	    		f["qualifier"] == "PT"
	    	}
	    	unless pax_reference.blank?
	    		numbers = pax_reference.collect { |pf| pf["number"] }
	    		unless numbers.blank?
	    			numbers.each { |n|
	    				pax = pnr_info.search_passenger(n)
	    				unless pax.nil?
		    				if pax['passengerData'].is_a?(Array) then 
		    					unless inf_fare?
		    						paxs.push(pax['passengerData'][0]) 
		    					else
		    						paxs.push(pax['passengerData'][1]) #En caso que se tarifa infante
		    					end
						    else
						    	paxs.push(pax['passengerData']) 
						    end
						end
	    			}
	    		end
	    	end
	    	return paxs
	    end

	    def inf_fare?
	    	text = fare_element["tstFreetext"]
	    	if text.is_a?(Array) then
	    		text.each { 
	    			|t| 
	    			return true if !t["longFreetext"].nil? && t["longFreetext"].include?("INF")  
	    		}
	    	else
	    		return true if !text["longFreetext"].nil? && text["longFreetext"].include?("INF")  
	    	end
	    	return false
	    end

	end

	#Wrapper que contiene los tickets
	class TicketsWrapper
		attr_accessor :tickets, :data, :pnr_info

		def initialize(pnr_data, pnr_info) 
		  self.pnr_info = pnr_info
	      self.data = pnr_data
	      self.tickets = get_tickets
	    end

	    def ticket_elements
	    	elements = self.data["soapCOLONBody"]["PNR_Reply"]["dataElementsMaster"]["dataElementsIndiv"]
	    	return elements.select { |e| e['elementManagementData']['segmentName'] == "FA" }
	    end

	    #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_number(text_element)
           temp = text_element.split("/")
		   temp2 = temp[0].split("-")
		   temp2[1]
	    end

	    #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_pax_name(element)
	    	reference = element["referenceForDataElement"]["reference"]
	    	pax_element = reference.select { |r| r['qualifier'] == "PT" }
	    	unless pax_element.empty?
			    number = pax_element[0]["number"]
			    pax = pnr_info.search_passenger(number)
			    pax_data = pax['passengerData']['travellerInformation']
		    	"#{pax_data['traveller']['surname']} #{pax_data['passenger']['firstName']}"
		    else
		    	""
		    end
	    end

	    #devuelve la tarifa base del ticket
	    def ticket_base_fare(text_element)
	    	response = ""
	    	temp = text_element.split("/")
	    	unless temp[2].nil?
			    response = temp[2][3..(temp[2].size - 1)] if temp[2].include?("ARS")
			end
	    	return response
	    end

	     #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_airline(text_element)
	    	response = ""
	    	temp = text_element.split("/")
	    	unless temp[1].nil?
			    response = temp[1][2..(temp[1].size - 1)] if temp[1].include?("ET")
			end
	    	return response
	    end

	    def create_ticket(element)
	    	number = ticket_number(element["otherDataFreetext"]["longFreetext"])
	    	void = false
	    	pax_name = ticket_pax_name(element)
	    	base_fare = ticket_base_fare(element["otherDataFreetext"]["longFreetext"])
	    	airline = ticket_airline(element["otherDataFreetext"]["longFreetext"])
	    	{number: number, void: void, pax_name: pax_name, base_fare: base_fare, airline: airline}
	    	#{number: number, void: false}
	    	# {number: number, void: false, pax_name: "", base_fare: "", airline: ""}
	    end

	    def get_tickets
	    	response = []
	    	te = ticket_elements
	    	unless te.nil?
	    		if te.is_a?(Array) then 
	    			response = te.collect { |a| create_ticket(a)}
	    		else
	    			response << create_ticket(te)
	    		end
	    	end
	    	return response
	    end

	end

	#Wrapper a partir del elemento travel_itinerary
	class PnrInfoWrapper
		attr_accessor :data, :pnr_code

		def initialize(pnr_code, pnr_json) 
	      self.pnr_code = pnr_code
	      self.data = pnr_json
	    end

	    def passengers_data
	    	data["soapCOLONBody"]["PNR_Reply"]["travellerInfo"]
	    end

	    def routes_data
	    	data["soapCOLONBody"]["PNR_Reply"]["originDestinationDetails"]["itineraryInfo"]
	    end

	    def fe_data
	    	elements = data["soapCOLONBody"]["PNR_Reply"]["dataElementsMaster"]["dataElementsIndiv"]
	    	return elements.select { |e| e['elementManagementData']['segmentName'] == "FE" }
	    end

	    def tk_data
	    	elements = data["soapCOLONBody"]["PNR_Reply"]["dataElementsMaster"]["dataElementsIndiv"]
	    	return elements.select { |e| e['elementManagementData']['segmentName'] == "TK" }
	    end

	    def fares_data
	    	data["soapCOLONBody"]["PNR_Reply"]["tstData"]
	    end

	    def fares_objects

	    end

	    def cant_pax
	    	cant = 0
	    	if passengers_data.is_a?(Array) then 
		    	passengers_data.each { 
		    		|p| 
		    		if p['passengerData'].is_a?(Array) then 
		    			cant += p['passengerData'].size
		    		else
		    			cant += 1 
		    		end 
				} 
		    else
		    	cant = 1
		    end
		    return cant
	    end

	    def search_passenger(number)
	    	if passengers_data.is_a?(Array) then    
		    	paxs = passengers_data.select { |e| 
		    		e['elementManagementPassenger']['reference']['qualifier'] == "PT" && e['elementManagementPassenger']['reference']['number'] == "#{number}" 
		    	}
		    	return paxs[0] unless paxs.empty?
	    	else
	    		pf = passengers_data['elementManagementPassenger']['reference']
	    		return passengers_data if pf['qualifier'] == "PT" && pf['number'] == "#{number}"
		    end
		    return nil 
	    end

	    def tickets
	    	tw = TicketsWrapper.new(self.data, self)
	    	tw.tickets
	    end
	end

	# Hace los print de la información que obtiene del pnr
	class PnrPrinter
		attr_accessor :pnr_info

		def initialize(pnr_info_wrapper)
	      self.pnr_info = pnr_info_wrapper
	    end


	    def text_route(r)
	    	unless r['travelProduct']['productDetails']['identification'] == "ARNK"
	    		r_date = r['travelProduct']['product']
	    		a_date = ParserDate.new(r_date['arrDate'] + r_date['arrTime'],true)
	    		d_date = ParserDate.new(r_date['depDate'] + r_date['depTime'],true)
		    	return "#{r['elementManagementItinerary']['lineNumber']} "\
		    		"#{r['travelProduct']['companyDetail']['identification']} "\
		    		"#{r['travelProduct']['productDetails']['identification']} "\
		    		"#{r['travelProduct']['productDetails']['classOfService']} "\
		    		"#{d_date.get_amadeus_date} "\
		    		"#{r['relatedProduct']['quantity']}*"\
					"#{r['travelProduct']['boardpointDetail']['cityCode']}"\
					"#{r['travelProduct']['offpointDetail']['cityCode']} "\
					"#{r['relatedProduct']['status']}"\
					"#{r['relatedProduct']['quantity']} "\
					"#{d_date.get_amadeus_time} "\
					"#{a_date.get_amadeus_time} "\
					"#{a_date.get_amadeus_date} "\
					"E "\
					"#{r['itineraryReservationInfo']['reservation']['companyId']}/"\
					"#{r['itineraryReservationInfo']['reservation']['controlNumber']}"\
			else
	    		return "#{r['elementManagementItinerary']['lineNumber']} "\
		    		"#{r['travelProduct']['productDetails']['identification']} "\
	    	end
	    end

	    #El texto de los datos de cada pax
	    def unique_pax(pax_data)
	    	if pax_data['travellerInformation']['passenger'].is_a?(Array) then 
		    	type_pax = "ADLWINF" #Adulto con infante
		    	surname = "#{pax_data['travellerInformation']['traveller']['surname']}"
	    		name = "#{pax_data['travellerInformation']['passenger'][0]['firstName']}" 
	    		inf_name = "#{pax_data['travellerInformation']['passenger'][1]['firstName']}" 
		    else
		    	type_pax = pax_data['travellerInformation']['passenger']['type']
	    		surname = "#{pax_data['travellerInformation']['traveller']['surname']}"
	    		name = "#{pax_data['travellerInformation']['passenger']['firstName']}" 
		    end
	    	
	    	if type_pax == "INF"
	    		response = "(INF#{surname}/#{name})"
	    	elsif type_pax == "ADLWINF"
				response = "#{surname}/#{name}(INF/#{inf_name})"
	    	elsif type_pax.nil? 
	    		response = "#{surname}/#{name}"
	    	else
	    		response = "#{surname}/#{name}(#{type_pax})"
	    	end
	    	return response
	    end

	    def text_pax(p)
	    	response = "#{p['elementManagementPassenger']['lineNumber']}." 
	    	if p['passengerData'].is_a?(Array) then 
		    	p['passengerData'].select { |pax|
		    	 response += "#{unique_pax(pax)} " 
		    	}
		    else
		    	response += "#{unique_pax(p['passengerData'])} " 
		    end
	    	return response
	    end

	    #Los dato de cada tarifa
	    def text_fare(f, pnr_info)
	    	fare_print = FareData.new(f, pnr_info)
	    	response = "<p>#{fare_print.fare_paxs}</p>"
	    	response += "<p>#{fare_print.fare_base_text}</p>" 
	    	response += "<p>#{fare_print.fare_equiv_text}</p>" 
	    	response += "<p>#{fare_print.taxes_tables}</p>" 
	    	response += "<p>#{fare_print.fare_total_text}</p>" 
	    	return response
	    end

	end

	class PnrHtmlPrinter < PnrPrinter

	    def print_passengers
	    	response = ""
	    	if pnr_info.passengers_data.is_a?(Array) then 
		    	pnr_info.passengers_data.select { |p| response += "#{text_pax(p)} " }
		    	return "<p>#{response}</p>"
		    else
		    	return "<p>#{text_pax(pnr_info.passengers_data)}</p>" 
		    end
	    end

	    def print_routes
	    	unless pnr_info.routes_data.nil?
	    		if pnr_info.routes_data.is_a?(Array) then
		    		text_routes = pnr_info.routes_data.collect { 
		    			|r| 
		    			"<p>#{text_route(r)}</p>"\
		    		}
		    		return text_routes.join("")
		    	else
		    		return "<p>#{text_route(pnr_info.routes_data)}</p>"
		    	end
		    else
	    		return ""
	    	end
	    end

	    def print_description
	    	return  "<p>#{pnr_info.pnr_code}</p>" + print_passengers + print_routes + print_fares + "<HR WIDTH='90%''>"
	    end

	    def print_fares
	    	response = ""
	    	unless pnr_info.fares_data.nil?	
	    		if pnr_info.fares_data.is_a?(Array) then
		    		text_fares = pnr_info.fares_data.collect { 
		    			|f| 
		    			"<p>#{text_fare(f, pnr_info)}</p>"\
		    		}
		    		response += text_fares.join("")
		    	else
		    		response += "<p>#{text_fare(pnr_info.fares_data, pnr_info)}</p>"
		    	end
		    	tls = TotalsData.new(pnr_info)
		    	response += tls.line_totals
	    	end
	    	return response
	    end
	end
end