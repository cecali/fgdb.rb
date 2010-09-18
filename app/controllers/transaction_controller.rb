class TransactionController < ApplicationController
  layout :check_for_receipt

  before_filter :set_defaults
  before_filter :be_a_thing

  def set_defaults
    @action_name=action_name
    @return_to_search = "false"
  end

  def be_a_thing
    set_transaction_type((controller_name()).singularize)
  end

  protected

  def check_for_receipt
    case action_name
    when /receipt/ then "receipt_invoice.html.erb"
    else                "with_sidebar.html.erb"
    end
  end

  def authorized_only
    requires_privileges("role_admin")
  end

  public

  def get_system_contract
    s = nil
    if params[:system_id].to_s == params[:system_id].to_i.to_s
      s = System.find_by_id(params[:system_id])
    end
    v = (s ? s.contract_id : -1)
    v2 = (s ? s.covered : nil)

    render :update do |page|
      page << "internal_system_contract_id = #{v.to_s.to_json}";
      page << "system_covered_cache[#{params[:system_id].to_json}] = #{v2.inspect.to_json}";
      page << "ge_done();"
    end
  end

  def get_storecredit_amount
    s = StoreCredit.find_by_id(params[:id])
    msg = nil
    v = -1
    if s
      if s.spent?
        msg = "This store credit has already been spent"
      else
        v = s.amount_cents
      end
    else
      msg = "A store credit with that ID does not exist"
    end
    v = (s && !s.spent? ? s.amount_cents : -1)
    render :update do |page|
      page << "internal_storecredit_amount = #{v.to_s.to_json};";
      page << "storecredit_errors_cache[#{params[:id]}] = #{msg.to_json};"
      page.hide loading_indicator_id("payment_line_item")
    end
  end

  def get_sale_exists
    s = Sale.find_by_id(params[:id])
    s = !! s
    render :update do |page|
      page << "internal_sale_exists = #{s.to_json};";
      page.hide loading_indicator_id("line_item")
    end
  end

  def update_stuff
    @show_wrapper = false
    params[:continue] = false
  end

  def component_update
    update_stuff
    search
  end

  def search
    @show_wrapper = true if @show_wrapper.nil?
    @conditions = Conditions.new
    @model = model
    if params[:dont_show_wrapper]
      update_stuff
    end

    if params[:continue] && !session[:search_bookmark].nil?
      params[:conditions] = session[:search_bookmark][:conditions]
      params[:page] = session[:search_bookmark][:page]
    end

    if params[:conditions] == nil
      params[:conditions] = {}
      @transactions = nil
      session[:search_bookmark] = nil
    else
      @sort_sql = @model.default_sort_sql
      @conditions.apply_conditions(params[:conditions])

      search_options = {
        :order => @sort_sql,
        :per_page => 20,
        :include => [:gizmo_events],
        :conditions => @conditions.conditions(@model),
        :page => params[:page]
      }

      if @model.new.respond_to?( :payments )
        search_options[:include] << :payments
      end

      session[:search_bookmark] = {
        :conditions => params[:conditions],
        :page => params[:page]
      }
      @transactions = @model.paginate( search_options )
    end

    @return_to_search = "true"

    render :action => "search", :layout => @show_wrapper
  end

  def index
    new
    render :action => 'new'
  end

  def new
    @transaction ||= model.new(params[@gizmo_context.name.to_sym])
    @successful ||= true

    @conditions = Conditions.new
    @conditions.apply_conditions((default_condition + "_enabled") => "true")
    @transactions = model.find(:all, :conditions => @conditions.conditions(model), :limit => 15, :order => default_condition + " DESC")
  end

  def create
    begin
      @transaction = model.new(params[@transaction_type])
      _apply_line_item_data(@transaction)
      @successful =  @transaction.save
    rescue
      flash[:error], @successful = $!.to_s + "<hr />" + $!.backtrace.join("<br />").to_s, false
    end

    render :action => 'create.rjs'
  end

  def create_without_ajax
    begin
      @transaction = model.new(params[@transaction_type])
      _apply_line_item_data(@transaction)
      @successful =  @transaction.save
    rescue
      flash[:error], @successful = $!.to_s + "<hr />" + $!.backtrace.join("<br />").to_s, false
    end
    if @successful
      if @transaction_type == "sale" or (@transaction_type == "donation" and @transaction.contact_type != "dumped")
        @receipt = @transaction.id
      end
      @transaction = model.new
    end
    new
    render :action => 'new'
  end

  def edit
    begin
      @transaction = model.find(params[:id])
      @successful = !@transaction.nil?
      @initial_page_load = true
    rescue
      flash[:error], @successful = $!.to_s, false
    end

    @return_to_search = params[:return_to_search] == "true"

    @conditions = Conditions.new
    @conditions.apply_conditions((default_condition + "_enabled") => "true")
    @transactions = model.find(:all, :conditions => @conditions.conditions(model), :limit => 15, :order => default_condition + " DESC")
  end

  def update
    begin
      @transaction = model.find(params[:id])
      @transaction.attributes = params[@transaction_type]
      _apply_line_item_data(@transaction)
      @successful =  @transaction.save
    rescue
      flash[:error], @successful  = $!.to_s + "<hr />" + $!.backtrace.join("<br />").to_s, false #, false #
    end

    render :action => 'update.rjs'
  end

  def update_without_ajax
    begin
      @transaction = model.find(params[:id])
      @transaction.attributes = params[@transaction_type]
      _apply_line_item_data(@transaction)
      @successful =  @transaction.save
    rescue
      flash[:error], @successful  = $!.to_s + "<hr />" + $!.backtrace.join("<br />").to_s, false #, false #
    end

    if @successful
      if @transaction_type == "sale" or (@transaction_type == "donation" and @transaction.contact_type != "dumped")
        @receipt = @transaction.id
      end
      @transaction = model.new
    end

    new
    render :action => 'new'
  end

  def destroy
    begin
      @successful = model.find(params[:id]).destroy
    rescue
      @error = $!.to_s
      @successful = false
      flash[:error], @successful  = $!.to_s, false
    end
    render :action => "destroy.rjs"
  end

  def needs_attention
    begin
      @transaction = model.find(params[:id])
      @transaction.comments += "\nATTN: #{params[:comment]}"
      @transaction.needs_attention = true
      @successful = @transaction.save
    rescue
      flash[:error], @successful = $!.to_s, false
    end
  end

  def cancel
    @successful = true

    return render(:action => 'cancel.rjs')
  end

  def update_discount_schedule
    if params[@transaction_type][:contact_id]
      default_discount_schedule = Contact.find(params[@transaction_type][:contact_id]).default_discount_schedule
    else
      default_discount_schedule = DiscountSchedule.no_discount
    end
    render :update do |page|
      page << "set_new_val($('#{@transaction_type}_discount_schedule_id'), '#{default_discount_schedule.id}');"
    end
  end

  def receipt
    @txn = @transaction = model.find(params[:id])
    @context = @transaction_type
  end

  #######
  private
  #######

  def set_transaction_type(type)
    @transaction_type = type
    @gizmo_context = GizmoContext.send(@transaction_type) or raise "UGH"
  end

  def totals_id(params)
    @transaction_type + '_totals_div'
  end

  def model
    case @transaction_type
    when 'donation'
      Donation
    when 'sale'
      Sale
    when 'disbursement'
      Disbursement
    when 'recycling'
      Recycling
    when 'gizmo_return'
      GizmoReturn
    else
      raise "UNKNOWN TX-TYPE #{@transaction_type}"
    end
  end

  def _apply_line_item_data(transaction)
    if transaction.respond_to?(:payments)
      @payments = []
      payments = params[:payments] || {}
      for payment in payments.values
        p = Payment.new(payment)
        @payments << p
      end
      @transaction.payments = @payments
      transaction.payments.delete_if {|pmt| pmt.mostly_empty?}
    end
    params[:gizmo_events].values.each{|x| x[:gizmo_count] ||= 1} if @gizmo_context == GizmoContext.gizmo_return
    if transaction.respond_to?(:gizmo_events)
      lines = params[:gizmo_events] || {}
      @lines = []
      for line in lines.values
        @lines << GizmoEvent.new_or_edit(line.merge({:gizmo_context => @gizmo_context}))
      end
      @transaction.gizmo_events = @lines
    end
    transaction.gizmo_events.delete_if {|gizmo| gizmo.mostly_empty?}
  end
end
