require "gds_ws_support"
class Api::V1::PnrDataController < ApplicationController

  def get_pnr_info_from_gds
  	begin
      data_request = PnrDataRequest.new(pnr: params[:code], gds: params[:name])
      if data_request.valid? then

        response = GdsWsSupport.get_data(data_request.pnr, data_request.gds)
        description = response["printer"].print_description unless response["printer"].nil?
        data = { 
          "description" => description,
          "cant_pax" => response["cant_pax"],
          "status" => response["status"]
        }
     
        render json: data
      else
        render json: {"status" => "An error occurred: bad parametrs => "}
      end
    rescue Exception => e
      #notify_about_exception(e)
      render json: {"status" => "An error occurred: #{e}"}
    end
  end

  def write_remarks
    #begin
      data_request = PnrDataRequest.new(pnr: params[:pnr], gds: params[:gds],remarks: params[:remarks])
      
      if data_request.valid? then
        response = AptekTktWebServices::Services.write_remarks(data_request.pnr, data_request.gds, data_request.remarks)
        render json: {"status" => response}
      else
        render json: {"status" => "An error occurred: bad parametrs => "}
      end
    #rescue Exception => e
      #notify_about_exception(e)
    
    #  render json: {"status" => "An error occurred: #{e}"}
    #end
  end

end
