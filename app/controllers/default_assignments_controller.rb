class DefaultAssignmentsController < ApplicationController
  protected

  def get_required_privileges
    a = super
    a << {:privileges => ['admin_skedjul']}
    a
  end
  public

  layout :with_sidebar

  helper :skedjul

  def index
    @multi_enabled = true
    if params[:conditions]
      my_sort_prepend = params[:conditions][:sked_enabled] == "true" ? "(SELECT position FROM rosters_skeds WHERE sked_id = #{params[:conditions][:sked_id]} AND roster_id = volunteer_default_shifts.roster_id), " : "volunteer_default_shifts.roster_id, "
    @skedj = Skedjul.new({
      :conditions => ['contact', "sked", "roster", "volunteer_task_type", "assigned", "weekday"],

      :generate_param_key => "date_range",
      :generate_conditions => ["sked", "roster"],

      :block_method_name => "volunteer_default_shifts.volunteer_default_events.weekday_id",
      :block_method_display => "volunteer_default_shifts.volunteer_default_events.weekdays.name",
      :block_start_time => "volunteer_default_shifts.volunteer_default_events.weekdays.start_time",
      :block_end_time => "volunteer_default_shifts.volunteer_default_events.weekdays.end_time",
#      :default_view => "by_slot",
                           :table_head_partial => "default_assignments/multi_edit",
                           :cell_onclick => "selection_toggle",

                            :left_unique_value => "default_assignments.left_method_name",
                               :left_method_name => "default_assignments.left_method_name",
                           :left_sort_value => "#{my_sort_prepend}(coalesce(volunteer_task_types.description, volunteer_default_events.description)), volunteer_default_shifts.description, default_assignments.slot_number",
                               :left_table_name => "volunteer_default_shifts",
                               :left_link_action => "assign",
                               :title_between => 'volunteer_default_shifts.rosters.name',
#                               :break_between_difference => "default_assignments.slot_type_desc",

                               :thing_start_time => "default_assignments.start_time",
                               :thing_end_time => "default_assignments.end_time",
                               :thing_table_name => "default_assignments",
                               :thing_description => "time_range_s,display_name",
                               :thing_link_id => "default_assignments.id",
                               :thing_links => [[:reassign, :function, :contact_id], [:split, :remote, :contact_id],[:edit, :link], [:copy, :link, :volshift_stuck], [:destroy, :confirm, :contact_id]],


      }, params)

    @opts = @skedj.opts
    @conditions = @skedj.conditions
      @conditions.effective_on_enabled = "true"
      @conditions.effective_on_start = Date.today - 14
      @conditions.effective_on_end = Date.today + 60

    @skedj.find({:conditions => @skedj.where_clause, :include => [:contact => [], :volunteer_default_shift => [:volunteer_task_type, :volunteer_default_event]]})
    render :partial => "work_shifts/skedjul", :locals => {:skedj => @skedj }, :layout => :with_sidebar
    else
      render :partial => "index",  :layout => :with_sidebar
    end
  end

  def reassign
    assigned, available = params[:id].split(",")

    # readonly
    @assigned_orig = DefaultAssignment.find(assigned)
    @available = DefaultAssignment.find(available)

    # for write
    @assigned = DefaultAssignment.find(assigned)
    @new = DefaultAssignment.new # available

    # do it
    @assigned.volunteer_default_shift_id = @available.volunteer_default_shift_id
    @assigned.slot_number = @available.slot_number
    @assigned.start_time = @available.start_time if (@assigned.start_time < @available.start_time) or (@assigned.start_time >= @available.end_time)
    @assigned.end_time = @available.end_time if (@assigned.end_time > @available.end_time) or (@assigned.end_time <= @available.start_time)

    @new.start_time = @assigned_orig.start_time
    @new.end_time = @assigned_orig.end_time
    @new.volunteer_default_shift_id = @assigned_orig.volunteer_default_shift_id
    @new.slot_number = @assigned_orig.slot_number

    @assigned.save!
    @new.save!

    redirect_skedj(request.env["HTTP_REFERER"], @assigned.volunteer_default_shift.volunteer_default_event.weekday.name)
  end

  def split
    @assignment = DefaultAssignment.find(params[:id])
    render :update do |page|
      page.hide loading_indicator_id("skedjul_#{params[:skedjul_loading_indicator_id]}_loading")
      page << "show_message(#{(render :partial => "splitform").to_json});"
    end
  end

  def dosplit
    sp = params[:split].to_a.sort_by{|k,v| k}.map{|a| a[1].to_i}
    @assignment = DefaultAssignment.find(params[:id])
    old_end = @assignment.end_time
    @assignment.end_time = @assignment.send(:instantiate_time_object, "split_time", sp)
    new_end = @assignment.end_time
    success = ((@assignment.end_time < old_end) and (@assignment.end_time > @assignment.start_time))
   if success
      success = @assignment.save
      if success
        @assignment = DefaultAssignment.new(@assignment.attributes)
        @assignment.start_time = new_end
        @assignment.end_time = old_end
        success = @assignment.save
      end
    end
    render :update do |page|
      if success
        page.reload
#        page << "selection_toggle(#{params[:id]});"
#        page << "popup1.hide();"
      else
        page << "alert('split failed. this is probably due to the time not being within the correct range.');"
      end
      page.hide loading_indicator_id("split_assignment_form")
    end
  end

  def search
    @conditions = Conditions.new
    params[:conditions] ||= {}
    @conditions.apply_conditions(params[:conditions])
    @results = Assignment.paginate(:page => params[:page], :conditions => @conditions.conditions(Assignment), :order => "created_at ASC", :per_page => 50)
  end

  def copy
    @assignment = DefaultAssignment.find(params[:id])
    @my_url = {:action => "create_shift", :controller => "volunteer_default_events"}
    @assignment.id = nil
    @action_title = "Copying"
    edit
  end

  def edit
    if @assignment
      @assignments = [@assignment]
    else
      @assignments = params[:id].split(",").map{|x| DefaultAssignment.find(x)}
      @assignment = @assignments.first
    end
    @referer = request.env["HTTP_REFERER"]
    @my_url ||= {:action => "update", :id => params[:id]}
    render :action => 'edit'
  end

  def update
    @my_url = {:action => "update", :id => params[:id]}
    @assignments = params[:id].split(",").map{|x| DefaultAssignment.find(x)}
    rt = params[:default_assignment].delete(:redirect_to)

    ret = true
    @assignments.each{|x|
      if ret
        @assignment = x
        ret = !!(x.update_attributes(params[:default_assignment]))
      end
    }

    if ret
      flash[:notice] = 'DefaultAssignment was successfully updated.'
      redirect_skedj(rt, @assignment.volunteer_default_shift.volunteer_default_event.weekday.name)
    else
      @referer = rt
      render :action => "edit"
    end
  end

  def destroy
    @assignment = DefaultAssignment.find(params[:id])
    @assignment.destroy

    redirect_skedj(request.env["HTTP_REFERER"], @assignment.volunteer_default_shift.volunteer_default_event.weekday.name)
  end
end
