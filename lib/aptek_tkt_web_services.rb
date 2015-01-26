#!/bin/env ruby
# encoding: utf-8

require 'net/http'

module AptekTktWebServices
  FLEXI_APTOUR_ID = 2
  SABRE = "Sabre"
  AMADEUS = "Amadeus"
       
   
  module Services
    SABRE_URL_GET_PNR = "http://alpback.apteknet.com/SAB_GetPnr.php?"
    SABRE_URL_POST_REMARKS = "http://alpback.apteknet.com/SAB_Send2Pnr.php" 
    AMADEUS_URL_GET_PNR = "http://alpback.apteknet.com/AMA_GetPnr.php?"
    AMADEUS_URL_POST_REMARKS = "http://alpback.apteknet.com/AMA_Send2Pnr.php"
    
    def Services.get_pnr(pnr,gds)
      params = "pnr2get=#{pnr}"

      if gds == AptekTktWebServices::SABRE then
        uri = URI(URI.escape(SABRE_URL_GET_PNR + params))
      else
        uri = URI(URI.escape(AMADEUS_URL_GET_PNR + params))
      end  

      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      return data
    end
    
    def Services.write_remarks(pnr, gds, remarks)
      result = "HTTP ERROR"

      if gds == AptekTktWebServices::SABRE then
       	uri = URI(SABRE_URL_POST_REMARKS)
      else
       	uri = URI(AMADEUS_URL_POST_REMARKS)
      end
        
      response = Net::HTTP.post_form(uri, 
        {'pnr2get' => pnr, 
        'remarksagrabar' => remarks.join(",")}
      )

      data = JSON.parse(response.body)
      if response.code.to_i == 200 then
        result = data["error_status"].to_s
      end
        
      return result
    end
  end
 
end