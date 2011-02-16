class DisktestRunsController < ApplicationController
  layout :with_sidebar

  def index
    search
  end

  def search
    @error = params[:error]
    if !params[:conditions]
      params[:conditions] = {:created_at_enabled => "true"}
    end
    @conditions = Conditions.new
    @conditions.apply_conditions(params[:conditions])
    @disktest_runs = DisktestRun.paginate(:page => params[:page], :conditions => @conditions.conditions(DisktestRun), :order => "created_at ASC", :per_page => 50)
    render :action => "index"
  end
end
