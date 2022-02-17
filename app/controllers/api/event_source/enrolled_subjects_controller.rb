module Api
  module EventSource
    class EnrolledSubjectsController < ApplicationController

      def index
        render :status => 200, :json => SubscriberInventory.subscriber_ids_for(read_filter_params)
      end

      def show
        member_id = params[:enrolled_subject].present? ?  params[:enrolled_subject][:id] : params[:id]
        person = Person.find_for_member_id(member_id)
        if person.blank?
          render :status => 404, :nothing => true
        else
          render :status => 200, :json => SubscriberInventory.coverage_inventory_for(person, read_filter_params)
        end
      end

      def read_filter_params
        filter_parameters = Hash.new
        hios_param = params[:hios_id]
        year_param = params[:year]
        start_time = params[:start_time]
        end_time = params[:end_time]
        filter_parameters.merge!(hios_id: hios_param) if hios_param.present?
        filter_parameters.merge!(year: year_param.to_i) if year_param.present?
        filter_parameters.merge!(start_time: start_time) if start_time.present?
        filter_parameters.merge!(end_time: end_time) if end_time.present?
        filter_parameters
      end
    end
  end
end
