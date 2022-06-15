class EdiTransactionSetsController < ApplicationController
  def index
	  # @edi_transaction_sets = EdiTransactionSet.all
	  @edi_transaction_sets = Protocols::X12::TransactionSetEnrollment.limit(100)

    respond_to do |format|
	    format.html # index.html.erb
	    format.json { render json: @edi_transaction_sets }
	  end
  end

  def errors
    @q = params[:q]
    @carriers = Carrier.by_name
    @carrier = Carrier.find(params['carrier']) if params['carrier'].present?
    @to_date = (params["to_date"] || Date.today).to_date
    @from_date = (params["from_date"] || Date.new(2014,1,1)).to_date > @to_date ? @to_date : (params["from_date"] || Date.new(2014,1,1)).to_date
    @result_set = Protocols::X12::TransactionSetEnrollment.where("error_list" => {"$exists" => true, "$not" => {"$size" => 0}},
                                                                 "submitted_at" => (@from_date..@to_date)).search({search_string: @q, carrier: @carrier})
    @transactions = @result_set.page(params[:page]).per(15)
    authorize! params, @transactions || Protocols::X12::TransactionSetEnrollment
  end

  def show
		@edi_transaction_set = Protocols::X12::TransactionSetEnrollment.find(params[:id])

	  respond_to do |format|
		  format.html # index.html.erb
		  format.json { render json: @edi_transaction_set }
		end
  end

  private
    def carrier_map(name)
      c_hash = Carrier.all.to_a.inject({}){|result, c| result.merge({c.name => c.carrier_profiles.first.try(:fein)}) }
      @q = c_hash[name] if c_hash[name].present?
      @q
    end
end
