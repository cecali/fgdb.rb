class TillAdjustmentsController < ApplicationController
  # GET /till_adjustments
  # GET /till_adjustments.xml
  def index
    @till_adjustments = TillAdjustment.find(:all)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @till_adjustments }
    end
  end

  # GET /till_adjustments/1
  # GET /till_adjustments/1.xml
  def show
    @till_adjustment = TillAdjustment.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @till_adjustment }
    end
  end

  # GET /till_adjustments/new
  # GET /till_adjustments/new.xml
  def new
    @till_adjustment = TillAdjustment.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @till_adjustment }
    end
  end

  # GET /till_adjustments/1/edit
  def edit
    @till_adjustment = TillAdjustment.find(params[:id])
  end

  # POST /till_adjustments
  # POST /till_adjustments.xml
  def create
    @till_adjustment = TillAdjustment.new(params[:till_adjustment])

    respond_to do |format|
      if @till_adjustment.save
        flash[:notice] = 'TillAdjustment was successfully created.'
        format.html { redirect_to(@till_adjustment) }
        format.xml  { render :xml => @till_adjustment, :status => :created, :location => @till_adjustment }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @till_adjustment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /till_adjustments/1
  # PUT /till_adjustments/1.xml
  def update
    @till_adjustment = TillAdjustment.find(params[:id])

    respond_to do |format|
      if @till_adjustment.update_attributes(params[:till_adjustment])
        flash[:notice] = 'TillAdjustment was successfully updated.'
        format.html { redirect_to(@till_adjustment) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @till_adjustment.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /till_adjustments/1
  # DELETE /till_adjustments/1.xml
  def destroy
    @till_adjustment = TillAdjustment.find(params[:id])
    @till_adjustment.destroy

    respond_to do |format|
      format.html { redirect_to(till_adjustments_url) }
      format.xml  { head :ok }
    end
  end
end
