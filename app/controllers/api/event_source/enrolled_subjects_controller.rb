module Api
  module EventSource
    class EnrolledSubjectsController < ApplicationController
      # skip_before_filter :authenticate_user_from_token!
      # skip_before_filter :authenticate_me!
      # skip_before_filter :verify_authenticity_token

      def index
        year_param = params[:year]
        hios_param = params[:hios_id]
        if year_param.blank? || hios_param.blank?
          render :status => 422, :nothing => true
        else
          render :status => 200, :json => SubscriberInventory.subscriber_ids_for(hios_param, year_param.to_i)
        end
      end

      def show
        member_id = params[:subscriber_id] || params[:id]
        person = Person.find_for_member_id(member_id)
        if person.blank?
          render :status => 404, :nothing => true
        else
          render :status => 200, :json => SubscriberInventory.coverage_inventory_for(person, read_show_filter_params)
        end
      end

      def read_show_filter_params
        filter_parameters = Hash.new
        year_param = params[:year]
        hios_param = params[:hios_id]
        if !year_param.blank?
          filter_parameters[:year] = year_param.to_i
        end
        if !hios_param.blank?
          filter_parameters[:hios_id] = hios_param
        end
        filter_parameters
      end
    end
  end
end
