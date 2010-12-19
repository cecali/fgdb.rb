class WorkShiftsController < ApplicationController
  layout "skedjulnator"
  before_filter :skedjulnator_role, :except => [:staffsched]

  def index
    list
    render :action => 'list'
  end

  def staffsched
    @readonly = true
    @vacations = Vacation.find(:all, :order => 'effective_date, ineffective_date', :conditions => ["ineffective_date >= ?", Date.today])
    params["conditions"] = {:shift_date_enabled => "true", :shift_date_end_date => (Date.today + 60).to_s, :shift_date_start_date => Date.today.to_s, }
    params["opts"] = {:presentation_mode => "Preview"}

    list
    render :action => 'list'
  end

  helper :skedjul

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :create, :update ], # TODO: destroy should be in this list but the skedjul_links thing needs support for :post
         :redirect_to => { :action => :list }

  def list
    session["shift_return_to"] = "work_shifts"
    session["shift_return_action"] = "list"

    @skedj = Skedjul.new({
      :conditions => ["worker", "job"],
      :date_range_condition => "shift_date",

      :block_method_name => "work_shifts.shift_date",
      :block_method_display => "work_shifts.shift_date_display",
      :block_start_time => "weekdays.start_time",
      :block_end_time => "weekdays.end_time",

      :left_unique_value => "worker_id",
      :left_method_name => "workers.name",
      :left_table_name => "workers",
      :left_link_action => "edit",
      :left_link_id => "workers.id",

      :thing_start_time => "work_shifts.start_time",
      :thing_end_time => "work_shifts.end_time",
      :thing_table_name => "work_shifts",
      :thing_description => "display_name_skedj",
      :thing_link_id => "work_shifts.id",
      :thing_links => [[:copy, :popup], [:edit, :popup], [:destroy, :confirm]]

      }, params)

    @skedj.find({:include => [:job, :coverage_type, :worker, :weekday]})
  end


  def show
    @work_shift = WorkShift.find(params[:id])
  end

  def new
    @work_shift = WorkShift.new
  end

  def create
    @work_shift = WorkShift.new(params[:work_shift])
    if @work_shift.save
      flash[:notice] = 'WorkShift was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def copy
    @work_shift = WorkShift.find(params[:id])
    @work_shift2 = @work_shift.clone
    if @work_shift2.save
      flash[:notice] = 'WorkShift was successfully copied.'
      redirect_to :action => 'edit', :id => @work_shift2.id
    else
      render :action => 'new'
    end
  end

  def edit
    @work_shift = WorkShift.find(params[:id])
  end

  def update
    @work_shift = WorkShift.find(params[:id])
    if @work_shift.update_attributes(params[:work_shift])
      flash[:notice] = 'WorkShift was successfully updated.'
      if session["shift_return_to"] 
        redirect_to :controller => session["shift_return_to"], :action => session["shift_return_action"], :id => session["shift_return_id"]
      else
        redirect_to :action => 'list', :id => @work_shift
      end
    else
      render :action => 'edit'
    end
  end

  def destroy
    WorkShift.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
