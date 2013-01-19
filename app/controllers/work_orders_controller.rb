class WorkOrdersController < ApplicationController
  layout :with_sidebar

  protected
  def get_required_privileges
    a = super
    a << {:privileges => ['techsupport_workorders']}
    return a
  end
  before_filter :ensure_metadata
  def ensure_metadata
    @@rt_metadata ||= _parse_metadata
    @rt_metadata = @@rt_metadata
  end
  def _parse_metadata
    h = {}
    cur = nil
    File.readlines(File.join(RAILS_ROOT, "config/rt_metadata.txt")).each do |line|
      line.strip!
      if line.match(/^== (.+) ==$/)
        cur = $1
        h[cur] = []
      else
        h[cur] << line.gsub(/^"(.+)"$/) do $1 end
      end
    end
    return h
  end
  public

  def index
    @work_orders = [OpenStruct.new]
  end

  def new
    if params[:open_struct]
      @work_order = OpenStruct.new(params[:open_struct])
      @work_order.issues = params[:open_struct][:issue].to_a.select{|x| x.first == x.last}.map{|x| x.first}
      @work_order.issue = nil
    else
      @work_order = OpenStruct.new
    end
  end

  def edit
    @work_order = OpenStruct.new
  end

  def show
    if params[:id]
      if !(@contact = Contact.find_by_id(params[:contact_id].to_i))
        @data = nil
        @error = "The provided technician contact doesn't exist."
        return
      end
#      if (!@contact.user) or (!@contact.user.grantable_roles.include?(Role.find_by_name("TECH_SUPPORT")))
#        @data = nil
#        @error = "The provided technician contact doesn't have the tech support role."
#        return
#      end
      json = `#{RAILS_ROOT}/script/fetch_ts_data.pl #{params[:id].to_i}`
      begin
        @data = JSON.parse(json)
      rescue
        @data = nil
      end
      if @data.nil? || @data["ID"].to_i != params[:id].to_i
        @data = nil
        @error = "The provided ticket number does not exist."
        return
      end
      if @data && @data["Queue"] != "TechSupport"
        @data = nil
        @error = "The provided ticket number does not reference a valid TechSupport ticket."
        return
      end
      if @data && @data["System ID"]
        @system = System.find_by_id(@data["System ID"].to_i)
      end
    end
  end

  protected
  def parse_data
    @work_order = OpenStruct.new(params[:open_struct])
    @work_order.issues = params[:open_struct][:issue].to_a.select{|x| x.first == x.last}.map{|x| x.first}
    @work_order.issue = nil

    @data = {}
    @data["Issues"] = @work_order.issues.join(", ")
    @data["Technician ID"] = @work_order.receiver_contact_id
    @data["Adopter Name"] = @work_order.customer_name
    @data["ID"] = " not yet created"
    @data["Email"] = @work_order.email
    @data["Phone"] = @work_order.phone_number
    @data["OS"] = @work_order.os
    @data["Source"] = @work_order.box_source
    @data["Type of Box"] = @work_order.box_type
    @data["Initial Content"] = "Operating system info provided: " + @work_order.os
    @data["Technician ID"] = current_user ? current_user.contact_id.to_s : ""
  end

  public
  def create
    parse_data
#    if @work_order.save
#      flash[:notice] = 'OpenStruct was successfully created.'
#      redirect_to({:action => "show", :id => @work_order.id})
#    else
#      render :action => "new"
#    end
  end

  def submit
    parse_data

    requestor = User.current_user ? (User.current_user.email || "") : ""
    @data["Requestor"] = requestor

    tempfile = `mktemp -p #{File.join(RAILS_ROOT, "tmp", "tmp")}`.chomp 
    f = File.open(tempfile, 'w+')
    json = @data.to_json
    f.write(json)
    f.close

    t_id = `#{RAILS_ROOT}/script/create_work_order.pl #{tempfile}`
    File.delete(tempfile)
    redirect_to :action => :show, :id => t_id, :contact_id => current_user ? current_user.contact_id : nil
  end

  def update
    @work_order = OpenStruct.new

    if @work_order.update_attributes(params[:open_struct])
      flash[:notice] = 'OpenStruct was successfully updated.'
      redirect_to({:action => "show", :id => @work_order.id})
    else
      render :action => "edit"
    end
  end

  def destroy
    @work_order = OpenStruct.new
    @work_order.destroy

    redirect_to({:action => "index"})
  end
end
