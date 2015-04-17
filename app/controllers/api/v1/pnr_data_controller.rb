require "gds_ws_support"
class Api::V1::PnrDataController < ApplicationController

  def get_pnr_info
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
        render json: { status: "ERROR", error_msg: "An error occurred: bad parametrs : #{data_request.errors.full_messages}"}
      end
    rescue Exception => e
      #notify_about_exception(e)
      render json: { status: "ERROR", error_msg: "An error occurred: #{e}"}
    end
  end

  def write_remarks
    begin
      data_request = PnrDataRequest.new(pnr: params[:pnr], gds: params[:gds],remarks: params[:remarks])
      
      if data_request.valid? then
        response = AptekTktWebServices::Services.write_remarks(data_request.pnr, data_request.gds, data_request.remarks)
        if response == "OK" then
          data = {status: response}
        else
          data = {status: "ERROR", error_msg:  response}
        end
        render json: data
      else
        render json: { status: "ERROR", error_msg: "An error occurred: bad parametrs : #{data_request.errors.full_messages}"}
      end
    rescue Exception => e
      #notify_about_exception(e)
    
      render json: { status: "ERROR", error_msg: "An error occurred: #{e}"}
    end
  end

  def send_itinerary
     begin
      data_request = PnrDataRequest.new(pnr: params[:pnr], gds: params[:gds],mails: params[:mails])
      
      if data_request.valid? then
        response = GdsWsSupport.send_itinerary(data_request.pnr, data_request.gds, data_request.mails)
        if response == "OK" then
          data = {status: response}
        else
          data = {status: "ERROR", error_msg:  response}
        end
        render json: data
      else
        render json: { status: "ERROR", error_msg: "An error occurred: bad parametrs : #{data_request.errors.full_messages}"}
      end
    rescue Exception => e
      #notify_about_exception(e)
    
      render json: { status: "ERROR", error_msg: "An error occurred: #{e}"}
    end
  end

  def get_tickets_from_pnr
    begin
      data_request = PnrDataRequest.new(pnr: params[:code], gds: params[:name])
      if data_request.valid? then

        response = GdsWsSupport.get_data(data_request.pnr, data_request.gds)
        # description = response["printer"].print_description unless response["printer"].nil?
        data = { 
          "tickets" => response["tickets"],
          "status" => response["status"]
        }
     
        render json: data
      else
        render json: { status: "ERROR", error_msg: "An error occurred: bad parametrs : #{data_request.errors.full_messages}"}
      end
    rescue Exception => e
      #notify_about_exception(e)
      render json: { status: "ERROR", error_msg: "An error occurred: #{e}"}
    end
  end

end
