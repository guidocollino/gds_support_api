require 'sabre_web_services'

DataMapper.setup(:default, 'sqlite://' + Rails.root.to_s + "/db/sabre.db")

module SabreWsSupport

	###############SEND ITINERARY########################

	def self.set_mails(emails)
		elements = emails.collect { |e| "" }
		body = { 'ns:CustomerInfo' => { 'ns:Email' => elements, :attributes! => { 'ns:Email' => {	"Address" => emails } } } }

		response = SabreWebServices.call("TravelItineraryAddInfoRQ", body)

		if response["error"].nil? then
			res_body = response[:envelope][:body][:travel_itinerary_add_info_rs]
			if res_body[:application_results][:@status] == "Complete" then
				return "OK"
			end
		end

		return "ERROR"
	end

	def self.end_with_itinerary
		body = { 'ns:EndTransaction' =>	
			{ 'ns:Email' => 
				{ 'ns:Itinerary' => 
					{ 'ns:PDF' =>  "" , :attributes! => { 'ns:PDF' => { "Ind" => "true" } } } , 
					:attributes! => { 'ns:Itinerary' => { "Ind" => "true" } } }, 
				:attributes! => { 'ns:Email' => { "Ind" => "true" } } }, 'ns:Source' => "", 
			:attributes! => { 
				'ns:EndTransaction' => { "Ind" => "true" }, 
				'ns:Source' => { "ReceivedFrom" => "Aero" } } 
		} 

		response = SabreWebServices.call("EndTransactionRQ", body)

		if response["error"].nil? then
			res_body = response[:envelope][:body][:end_transaction_rs]
			if res_body[:application_results][:@status] == "Complete" then
				return "OK"
			end
		end

		return "ERROR"

	end

	def self.send_itinerary(pnr_code,emails)
		response = "ERROR"
		pnr_data = get_pnr_info(pnr_code)

		response = set_mails(emails) unless pnr_data.nil?

		response = end_with_itinerary unless response == "ERROR"

		return response

	end


	###############GET PNR DATA########################

	def self.get_pnr_info(pnr_code)
		body = { 'ns:MessagingDetails' => { 
    		 	'ns:Transaction' => "",
    		 	    :attributes! => { 'ns:Transaction' => { "Code" => "PNR" } } 
    		 	},
    		 	'ns:UniqueID' => "",
        			:attributes! => { 
              		'ns:UniqueID' => { "ID" => pnr_code }
              	}
	    	}

		response = SabreWebServices.call("TravelItineraryReadRQ", body)

		if response["error"].nil? then
			res_body = response[:envelope][:body][:travel_itinerary_read_rs]
			if res_body[:application_results][:@status] == "Complete" then
				return PnrInfoWrapper.new(pnr_code, res_body[:travel_itinerary])
				#else
				#response["error"] = "#{res_body[:application_results][:@status]} (#{res_body[:application_results][:error][:system_specific_results][:message]})"
			end
		end

		return nil
	end

	class ParserDate

		attr_accessor :origin_datetime

		def initialize(date_string, year = false)
			if year then
				self.origin_datetime = DateTime.strptime(date_string, '%Y-%m-%dT%H:%M')
			else
				self.origin_datetime = DateTime.strptime(date_string, '%m-%dT%H:%M')
	      	end
	    end

	    def get_sabre_date
	    	return origin_datetime.strftime("%d%^b")
	    end

	    def get_sabre_date_with_year
	    	return origin_datetime.strftime("%d%^b%y")
	    end

	    def get_sabre_time
	    	return origin_datetime.strftime("%H%M")
	    end


	end

	class TotalsPq
		attr_accessor :pqs, :base_fare, :equiv_fare, :taxes, :total

		def initialize(pqs)
			self.pqs = pqs
		    self.base_fare = 0
			self.equiv_fare = 0
			self.taxes = 0
			self.total = 0
			calculate
	    end

	    def calculate
	    	if self.pqs.is_a?(Array) then 
	    		#PARA EL CALCULO MANUAL , VER SI SIRVE EN EL CASO DE QUE HAYA INACTIVOS
		  #   	self.pqs.each { 
			 #    	|pq|  
	   #  			ai = pq[:priced_itinerary][:air_itinerary_pricing_info]
		  #   		tf = ai[:itin_total_fare]

			 #    	self.base_fare += tf[:base_fare][:@amount].to_f
		  #   		self.equiv_fare += tf[:equiv_fare][:@amount].to_f unless tf[:equiv_fare].blank?
		  #   		self.taxes += tf[:taxes][:tax][:@amount].to_f
		  #   		self.total += tf[:total_fare][:@amount].to_f
				# }
				last_pq = self.pqs.last
		    else
		    	last_pq = self.pqs
		    end 
		    
		    itf = last_pq[:priced_itinerary][:air_itinerary_pricing_info][:itin_total_fare]
	    	totals = itf[:totals]
		    self.base_fare += totals[:base_fare][:@amount].to_f
		    self.equiv_fare += totals[:equiv_fare][:@amount].to_f unless totals[:equiv_fare].blank?
		    self.taxes += totals[:taxes][:tax][:@amount].to_f
		    self.total += totals[:total_fare][:@amount].to_f
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
	end

	#Wrapper que contiene los tickets
	class TicketsWrapper
		attr_accessor :tickets, :accounting, :tickets_void, :ticketing

		def initialize(data) 
	      self.accounting = data[:accounting_info]
	      self.ticketing = data[:itinerary_info][:ticketing]
	      self.tickets_void = get_tickets_void
	      self.tickets = get_tickets
	    end

	    #devuelve el numero si es void, sino nil
	    def ticket_void_number(ticketing_element)
	    	text = ticketing_element[:@e_ticket_number]
	    	unless text.nil?
	    		if text.include?("*VOID*") then
	    			temp = text.split("-")
	    			number = temp[0].last(10)
	    			return number
	    		end
	    	end
	    	return nil
	    end

	    def get_tickets_void
	    	response = []
	    	tk = self.ticketing
	    	unless tk.nil?
	    		if tk.is_a?(Array) then 
	    			tk.each { 
	    				|t| 
	    				number = ticket_void_number(t)
	    				response << number unless number.nil?
	    			}
	    		else
	    			number = ticket_void_number(tk)
	    			response << number unless number.nil?
	    		end
	    	end
	    	return response
	    end

	    #devuelve el ticket completo o nil si no es conjuncion
	    def create_conjunction_ticket(ticketing_element)
	    	text = ticketing_element[:@e_ticket_number]
	    	unless text.nil?
	    		temp = text.split("-")
	    		temp_number = temp[0]
	    		temp_number = temp_number.gsub("TE", "")
	    		temp_number.strip
	    		if temp_number.include?("/") then
	    			temp = temp_number.split("/")
	    			number = temp[0].last(10)
	    			number_conj = temp[1] 
	    			number = number[0..7] + number_conj
	    			return {number: number, void: false, pax_name: "Conjunción", base_fare: "", airline: ""}
	    		end
	    	end
	    	return nil
	    end

	    def get_conjunction_ticket(accounting_element)
	    	response = nil
	    	origin_number = ticket_number(accounting_element)
	    	tk = self.ticketing
	    	unless tk.nil?
	    		temp_conj = nil 
	    		if tk.is_a?(Array) then 
	    			temp_conj = tk.select { |t| t[:@e_ticket_number].include?(origin_number) unless t[:@e_ticket_number].nil? }
	    			temp_conj = temp_conj.first unless temp_conj.empty?
	    		else
	    			
	    			if tk[:@e_ticket_number].include?(origin_number)
	    				temp_conj = tk
	    			end unless tk[:@e_ticket_number].nil?
	    		end
	    		unless temp_conj.nil?
	    			number = create_conjunction_ticket(temp_conj)
	    			response = number unless number.nil?
	    		end
	    	end
	    	return response
	    end

	    #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_number(accounting_element)
	    	accounting_element[:document_info][:document][:@number]
	    end

	    #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_pax_name(accounting_element)
	    	accounting_element[:person_name]
	    end

	    #devuelve la tarifa base del ticket
	    def ticket_base_fare(accounting_element)
	    	accounting_element[:base_fare][:@amount]
	    end

	     #devuelve el umero de ticket del elemento de accounting_info
	    def ticket_airline(accounting_element)
	    	accounting_element[:airline][:@code]
	    end

	    def create_ticket(accounting_element)
	    	number = ticket_number(accounting_element)
	    	void = self.tickets_void.include?(number)
	    	pax_name = ticket_pax_name(accounting_element)
	    	base_fare = ticket_base_fare(accounting_element)
	    	airline = ticket_airline(accounting_element)
	    	{number: number, void: void, pax_name: pax_name, base_fare: base_fare, airline: airline}
	    end

	    def get_tickets
	    	response = []
	    	ai = self.accounting
	    	unless ai.nil?
	    		if ai.is_a?(Array) then 
	    			ai.each { 
	    				|a|
	    				response << create_ticket(a)
	    				tconj = get_conjunction_ticket(a)
	    				response << tconj unless tconj.nil?
	    			}
	    		else
	    			response << create_ticket(ticket_number(ai))
	    			tconj = get_conjunction_ticket(ai)
	    			response << tconj unless tconj.nil?
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
	    	data[:customer_info][:person_name]
	    end

	    def routes_data
	    	data[:itinerary_info][:reservation_items][:item] unless data[:itinerary_info][:reservation_items].nil?
	    end

	    def itinerary_ref
	    	data[:itinerary_ref]
	    end

	    def pq_data
	    	price_quotes = nil
	    	unless data[:itinerary_info][:itinerary_pricing].nil?
	    		price_quotes = data[:itinerary_info][:itinerary_pricing][:price_quote]
	    		if price_quotes.is_a?(Array) then 
	    			price_quotes = price_quotes.select { |pq| !pq_inactive?(pq)}
	    		else
	    			price_quotes = price_quotes unless pq_inactive?(price_quotes)
	    		end
	    	end
	    	return price_quotes
	    end

	    def cant_pax
	    	if passengers_data.is_a?(Array) then 
		    	return passengers_data.size
		    else
		    	return 1
		    end
	    end

	    def pq_inactive?(pq)
	    	return pq[:misc_information][:signature_line][:@status] == "INACTIVE"
	    end

	    def tickets
	    	tw = TicketsWrapper.new(self.data)
	    	tw.tickets
	    end

	end

    #--------------------------------PRINTERS--------------------------------------

	# Hace los print de la información que obtiene del pnr
	class PnrPrinter
		attr_accessor :pnr_info

		def initialize(pnr_info_wrapper)
	      self.pnr_info = pnr_info_wrapper
	    end

	    def text_route(r)
	    	response = ""
	    	unless r[:flight_segment].nil?
		    	response = "#{r[:flight_segment][:@segment_number].to_i} "
		    	response += "#{r[:flight_segment][:marketing_airline][:@code]}"
		    	response +=	"#{r[:flight_segment][:marketing_airline][:@flight_number]}"
		    	response +=	"#{r[:flight_segment][:@res_book_desig_code]} "
				response +=	"#{(ParserDate.new(r[:flight_segment][:updated_departure_time])).get_sabre_date} "
				response +=	"#{r[:flight_segment][:@day_of_week_ind]} "
				response +=	"#{r[:flight_segment][:origin_location][:@location_code]}"
				response +=	"#{r[:flight_segment][:destination_location][:@location_code]} "
				response +=	"#{r[:flight_segment][:@status]}#{r[:flight_segment][:@number_in_party].to_i} "
				response +=	"#{(ParserDate.new(r[:flight_segment][:updated_departure_time])).get_sabre_time} "
				response +=	"#{(ParserDate.new(r[:flight_segment][:updated_arrival_time])).get_sabre_time} "
				response +=	"/#{r[:flight_segment][:supplier_ref][:@id]} "
				response +=	"#{if r[:flight_segment][:@e_ticket] then '/E' end  }"
			end
			return response
	    end

	    def text_route_scale(r)
	    	fi = 0
	    	fl = r.size - 1
	    	response = "#{r[:flight_segment][fi][:@segment_number].to_i} "
	    	response += "#{r[:flight_segment][fi][:marketing_airline][:@code]}"
	    	response +=	"#{r[:flight_segment][fi][:marketing_airline][:@flight_number]}"
	    	response +=	"#{r[:flight_segment][fi][:@res_book_desig_code]} "
			response +=	"#{(ParserDate.new(r[:flight_segment][fi][:updated_departure_time])).get_sabre_date} "
			response +=	"#{r[:flight_segment][fi][:@day_of_week_ind]} "
			response +=	"#{r[:flight_segment][fi][:origin_location][:@location_code]}"
			response +=	"#{r[:flight_segment][fl][:destination_location][:@location_code]} "
			response +=	"#{r[:flight_segment][fi][:@status]}#{r[:flight_segment][fi][:@number_in_party].to_i} "
			response +=	"#{(ParserDate.new(r[:flight_segment][fi][:updated_departure_time])).get_sabre_time} "
			response +=	"#{(ParserDate.new(r[:flight_segment][fl][:updated_arrival_time])).get_sabre_time} "
			response +=	"/#{r[:flight_segment][fi][:supplier_ref][:@id]} "
			response +=	"#{if r[:flight_segment][fi][:@e_ticket] then '/E' end  }"
			return response
	    end


	    #El texto de los datos de cada pax
	    def text_pax(p)
	    	return "#{p[:@name_number]} #{p[:surname]}/#{p[:given_name]} (#{p[:@passenger_type]}) #{p[:@name_reference]}" 
	    end

	    #El texto da la linea de totales de la tarifa dentro del pq
	    def text_pq_fare(pq)
	    	ai = pq[:priced_itinerary][:air_itinerary_pricing_info]
		    tf = ai[:itin_total_fare]
		    return 	"#{ai[:passenger_type_quantity][:@quantity].to_i}- "\
		    		"#{tf[:base_fare][:@currency_code]}#{tf[:base_fare][:@amount]} "\
		    		"#{tf[:equiv_fare][:@currency_code]}#{tf[:equiv_fare][:@amount]} "\
		    		"#{tf[:taxes][:tax][:@amount]}#{tf[:taxes][:tax][:@tax_code]} "\
		    		"#{tf[:total_fare][:@currency_code]}#{tf[:total_fare][:@amount]}"\
		    		"#{ai[:passenger_type_quantity][:@code]} " 
	    end

	    #El texto del desglose de impuestos del pq
	    def text_pq_taxes(pq)
	    	itf = pq[:priced_itinerary][:air_itinerary_pricing_info][:itin_total_fare]
	    	taxes = itf[:taxes][:tax_breakdown_code]
		   	return "#{itf[:taxes][:tax][:@tax_code]} #{taxes.join(" ")}"
	    end

	    def text_itinerary_ref(ir)
	    	return "#{ir[:source][:@home_pseudo_city_code]}.#{ir[:source][:@aaa_pseudo_city_code]}*#{ir[:source][:@creation_agent]} "\
	    	"#{(ParserDate.new(ir[:source][:@create_date_time],true)).get_sabre_time}/"\
	    	"#{(ParserDate.new(ir[:source][:@create_date_time],true)).get_sabre_date_with_year} "\
	    	"#{ir[:@id]} H "\
	    end

	end

	class PnrHtmlPrinter < PnrPrinter

	    def print_passengers
	    	if pnr_info.passengers_data.is_a?(Array) then 
		    	text_passengers = pnr_info.passengers_data.collect { 
		    		|p|  
		    		"<p>#{text_pax(p)}</p>" 
		    	}
		    	return text_passengers.join("")
		    else
		    	p = pnr_info.passengers_data
		    	return "<p>#{text_pax(p)}</p>" 
		    end
	    end

	    def print_routes
	    	unless pnr_info.routes_data.nil?
	    		arnks = []
	    		text_routes = []
		    	if pnr_info.routes_data.is_a?(Array) then 
			    	pnr_info.routes_data.each { 
			    		|p|  
			    		if p[:arunk].nil?
			    			if (p[:seats].nil? )
			    				if p[:flight_segment].is_a?(Array)
				    				route = "<p>#{text_route_scale(p)}</p>" 
				    				route += "<p>#{p[:flight_segment][0][:text]}</p>" unless (p[:flight_segment][0][:text].nil? )
				    				text_routes.push(route)
				    			else
				    				route = "<p>#{text_route(p)}</p>" 
				    				route += "<p>#{p[:flight_segment][:text]}</p>" unless (p[:flight_segment][:text].nil? )
				    				text_routes.push(route)
				    			end 
			    			end unless p[:flight_segment].nil?
			    			
			    		else
			    			arnks.push(p[:arunk])
			    		end
			    	}
			    	#para casos con ARNK
			    	unless arnks.empty?
			    		arnks.each {
			    			|a| text_routes.insert((a[:@segment_number].to_i - 1), "<p>#{a[:@segment_number].to_i} ARNK</p>")
			    		}
			    	end
			    	return text_routes.join("")
			    else
			    	p = pnr_info.routes_data
			    	return "<p>#{text_route(p)}</p>" 
			    end
		    else
	    		return ""
	    	end
	    end

	    def print_itinerary_ref
	    	ir = pnr_info.itinerary_ref
	    	return "<p>#{text_itinerary_ref(ir)}</p>"\

	    end

	    #No se esta usando pero permite imprimir todas las tarifas juntas en una tabla
	    def print_table_fares
	    	price_quotes = pnr_info.pq_data
	    	unless price_quotes.nil?
		    	table = "<table>"\
		    			"<tr>"\
	    				"<td></td>"\
	    				"<td>BASE FARE</td>"\
	    				"<td>EQUIV AMT</td>"\
	    				"<td>TAXES/FEES/CHARGES</td>"\
	    				"<td>TOTAL</td>"\
	  					"</tr>"
		    	
		    	if price_quotes.is_a?(Array) then 
		    		text_pqs = price_quotes.each { 
			    		|pq|  
			    		table += tr_pq_fare(pq)
			    		table += tr_pq_taxes(pq)
				    }
				    table += tr_pq_totals(price_quotes.last)
		    	else
		    		table += tr_pq_fare(price_quotes)
		    		table += tr_pq_taxes(price_quotes)
		    		table += tr_pq_totals(price_quotes)
		    	end

		    	table += "</table>"
		    	return 	table
		    else
		    	return ""
		    end
	    end

	    def print_table_fares_for_pq(pq)
	    	price_quotes = pnr_info.pq_data
		    table = "<table>"\
		    		"<tr>"\
	    			"<td></td>"\
	    			"<td>BASE FARE</td>"\
	    			"<td>EQUIV AMT</td>"\
	    			"<td>TAXES/FEES/CHARGES</td>"\
	    			"<td>TOTAL</td>"\
	  				"</tr>"
		    	
			table += tr_pq_fare(pq)
			table += tr_pq_taxes(pq)
			#table += tr_pq_totals(price_quotes.last)

		    table += "</table>"
		    return 	table
	    end

	    def table_pq_totals(pqs)
	    	totals = TotalsPq.new(pqs)
	    	response = "<p>TOTALES</p>"
	    	response += "<table>"\
		    		"<tr>"\
	    			"<td></td>"\
	    			"<td>BASE FARE</td>"\
	    			"<td>EQUIV AMT</td>"\
	    			"<td>TAXES/FEES/CHARGES</td>"\
	    			"<td>TOTAL</td>"\
	  				"</tr>"
	    	response += "<tr>"
	    	unless totals.blank?
	    		response += "<td></td>"
	    		response += "<td>#{totals.text_base_fare}</td>"
	    		response += "<td>#{totals.text_equiv_fare}</td>" 
	    		response += "<td>#{totals.text_taxes}</td>"
	    		response += "<td>#{totals.text_total}TTL</td>"
	    	end
	    	response += "</tr>"
	    	response += "</table>"
	    	return response
	    end

	    def print_expired

	    end

	    #Imprime todos los pq con la info de cotizacion, tarifas e info extra
	    def print_pq_data
	    	response = ""
	    	price_quotes = pnr_info.pq_data
	    	unless price_quotes.blank?
		    	if price_quotes.is_a?(Array) then 
		    		text_pqs = price_quotes.each { 
			    		|pq|  
			    		response += extra_info(pq)
				    }
		    	else
		    		response += extra_info(price_quotes)
		    	end
		    	response += table_pq_totals(price_quotes)
		    end
	    	return 	response
	    end

	    def print_description
	    	return  "<p>#{pnr_info.pnr_code}</p>" + 
	    			print_passengers + '</br>' + 
	    			print_routes + '</br>' +
	    			print_itinerary_ref + '</br>' + 
	    			print_pq_data + 
	    			"<HR WIDTH='90%''>"
		    
	    end

	    private
 
 		#----TABLA TARIFAS------------------------------------------------------

	     def tr_pq_fare(pq)
	    	response = ""
	    	ai = pq[:priced_itinerary][:air_itinerary_pricing_info]
		    tf = ai[:itin_total_fare]
		    response += "<tr>"
		    response += "<td>#{ai[:passenger_type_quantity][:@quantity].to_i}- </td>"
		    response += "<td>#{tf[:base_fare][:@currency_code]}#{tf[:base_fare][:@amount]}</td>"
		    equiv = tf[:equiv_fare].nil? ? "" : "#{tf[:equiv_fare][:@currency_code]}#{tf[:equiv_fare][:@amount]}"
		    response += "<td>#{equiv}</td>" 
		    response += "<td>#{tf[:taxes][:tax][:@amount]}#{tf[:taxes][:tax][:@tax_code]}</td>"
		    response += "<td>#{tf[:total_fare][:@currency_code]}#{tf[:total_fare][:@amount]}"
		    response += "#{ai[:passenger_type_quantity][:@code]}</td>"
		    response += "</tr>"
		    return response
	    end

	    #Las lineas de la tabla del desglose de impuestos del PQ
	    def tr_pq_taxes(pq)
	    	response = ""
	    	itf = pq[:priced_itinerary][:air_itinerary_pricing_info][:itin_total_fare]
	    	taxes = itf[:taxes][:tax_breakdown_code]
	    	code_tax = itf[:taxes][:tax][:@tax_code]
	    	div_taxes = taxes.each_slice(4).to_a
	    	div_taxes.each {
	    		|ts|
	    		response += "<tr>"
	    		response += "<td>#{code_tax}</td>"
	    		 ts.each { |t|  response += "<td>#{t}</td>" }
	    		response += "</tr>"
	    		code_tax = "" #el codigo del impuesto solo va en la primer fila
	    	}
		   	return response
	    end

	    def tr_pq_totals(pq)
	    	response = "<tr>"
	    	itf = pq[:priced_itinerary][:air_itinerary_pricing_info][:itin_total_fare]
	    	totals = itf[:totals]
	    	unless totals.blank?
	    		response += "<td></td>"
	    		response += "<td>#{totals[:base_fare][:@amount]}</td>"
	    		if totals[:equiv_fare].blank?
	    			response += "<td></td>" 
	    		else
	    			response += "<td>#{totals[:equiv_fare][:@amount]}</td>" 
	    		end
	    		response += "<td>#{totals[:taxes][:tax][:@amount]}</td>"
	    		response += "<td>#{totals[:total_fare][:@amount]}TTL</td>"
	    	end
	    	response += "</tr>"
	    	return response
	    end

	    #---FIN TABLA-------------------------------------------------------------

	    #El texto de la infomación extra que tiene el PQ
	    def extra_info(pq)
	    	response = ""
	    	ai = pq[:priced_itinerary][:air_itinerary_pricing_info]
		    tf = ai[:itin_total_fare]
	    	response += "<p>PQ #{pq[:@rph].to_i} #{pq[:priced_itinerary][:@input_message]}</p>"
	    	response +=	"<p>#{ai[:passenger_type_quantity][:@code]} #{ai[:passenger_type_quantity][:@quantity]} "
	    	response += print_table_fares_for_pq(pq)
	    	response +=	"#{ai[:ptc_fare_breakdown][:fare_basis][:@code]} </p>" unless ai[:ptc_fare_breakdown][:fare_basis].nil?
	    	response +=	"#{pq_restrinctions(ai[:ptc_fare_breakdown])}"
	    	return response
	    end

	    def pq_restrinctions(ptc)
	    	response = ""
	    	unless ptc.nil?
		    	restrictions = ptc[:res_ticketing_restrictions]
		    	if restrictions.is_a?(Array) then 
		    		restrictions.each { 
			    		|res|  
			    		response += "<p>#{res}</p>"
				    }
		    	else
		    		response += restrictions
		    	end unless restrictions.nil?
		    end

	    	return response
	    end

	end

	#-------------------------------------FIN PRINTERS------------------------------------------------------------

end