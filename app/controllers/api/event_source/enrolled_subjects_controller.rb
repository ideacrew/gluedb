module Api
  module EventSource
    class EnrolledSubjectsController < ApplicationController
      def index
        year_param = params[:year]
        hios_param = params[:hios_id]
        if year_param.blank? || hios_param.blank?
          render :status => 422, :nothing => true
        else
          plan = Plan.find_by_hios_id_and_year(
            hios_param,
            year_param.to_i
          )
          if plan.blank?
            render :status => 404, :nothing => true
          else
            render :status => 200, :json => SubscriberInventory.subscriber_ids_for(plan)
          end
        end
      end
    end
  end
end
