# TODO: reimplement Date class...we are converting between like 20
# different formats, and it's a PITA. tho, now that I have it all
# done, this todo will probably sit here for a few years...
# make it so that you have methods like .add_month and such
# cause there's a LOT of mess to do that kind of stuff
# it could also help clean up getting the second date range and the
# number between them, which are messy right now.

require_dependency RAILS_ROOT + '/app/helpers/conditions.rb'

class GraphicReportsController < ApplicationController
  layout :with_sidebar
  helper :conditions

  def get_temp_file # TODO: move this all within?
    file = File.join(RAILS_ROOT, "tmp", "tmp", params[:id].sub("$", "."))
    if !File.exists?(file)
      find_report
      @report = @klass.new
      @report.set_conditions(params[:conditions])
      @report.generate_report_data
      @report.gnuplot_stuff(file, params[:graph_n].to_i)
    end
    respond_to do |format|
      format.jpeg { render :text => File.read(file) }
    end
    File.unlink(file)
  end

  def view
    find_report
    @report = @klass.new
    @report.set_conditions(params[:conditions])
    @report.generate_report_data
  end

  def index
    @report_types = report_types
  end

  def index2
    @multi_enabled = true
    @valid_conditions = []
    find_report
    @breakdown_types = @klass.breakdown_types
    @valid_conditions = @klass.valid_conditions
  end

  #####################
  # Report type stuff #
  #####################
  private
  # list of report types
  def report_types
    return TrendReport.all_reports
  end

  # returns the title for that report type
  def find_report
    @klass ||= TrendReport.find_class(params[:conditions][:report_type])
  end

end

class TrendReport
  def gnuplot_stuff(tempfile, graph_n)
    Gnuplot.open do |gp|
      Gnuplot::Plot.new( gp ) do |plot|
        plot.set "title", self.graph_titles[graph_n]
        plot.set "terminal", "jpeg"
        plot.set "output", tempfile
        plot.ylabel ""
        plot.xlabel ""
        plot.xtic "rotate by 90"
        plot.grid
        string = "("
        string_a = []
        @graph_x_axis.each_with_index{|x,i|
          y = @x_axis[i]
          string_a << "\" #{y}\" #{x}"
        }
        string += string_a.join(", ")
        string += ")"
        plot.xtics string
        @data[graph_n].each do |k,v|
          plot.data << Gnuplot::DataSet.new( [@graph_x_axis, v] ) do |ds|
            ds.with = "linespoints"
            ds.title = k.to_s.titleize
          end
        end
      end
    end
  end

  #########################
  # Time range type stuff #
  #########################

  # list of breakdown types:

  # line breakdown types are when the whole date range is chunked up
  # based on something
  def line_breakdown_types
    TrendReport.line_breakdown_types
  end

  # bar breakdown types are when you want to compare things like
  # "which day of the week has the highest average" and such
  def bar_breakdown_types
    TrendReport.bar_breakdown_types
  end

  # convert a date object into the string that should be put on the x
  # axis
  def x_axis_for(date)
    case @conditions[:breakdown_type]
    when "Weekly"
      "Week of " + date.to_s
    when "Quarterly"
      string = date.strftime("%Y-Q")
      temp = date.strftime("%m").to_i
      hash = {:t1 => [1,2,3], :t2 => [4,5,6], :t3 => [7,8,9], :t4 => [10,11,12]}
      hash.each{|k,v|
        string += k.to_s.sub(/t/, "") if v.include?(temp)
      }
      string
    when "Daily"
      date.to_s
    when "Yearly"
      date.year.to_s
    when "Monthly"
      date.strftime("%b %y")
    when "Day of week"
      Date.strptime(date.to_s, "%w").strftime("%A")
    when "Hour"
      DateTime.strptime(date.to_s, "%H").strftime("%I:00 %p")
    else
      raise NoMethodError
    end
  end

  ###################
  # only if is_line #
  ###################

  # should return the total number of things that should be on the x
  # axis, minus one (this makes logical sense for simplicity)
  def number_between_them(end_date)
    case @conditions[:breakdown_type]
    when "Weekly"
      (end_date - @start_date).to_i / 7
    when "Quarterly"
      # EWWWW. this whole number_between_them needs to be
      # eliminated. just do a "do {} while {current_date <=
      # backed_up(end_date)}" or somethin like that instead of
      # "number_between_them(blah).times{}".
      num = 0
      curdate = @start_date
      until curdate == end_date
        curdate = Date.parse(increase_arr(curdate.to_s.split("-").map{|x| x.to_i}).join("-"))
        num += 1
      end
      return num
    when "Daily"
      (end_date - @start_date).to_i
    when "Yearly"
      end_date.year - @start_date.year
    when "Monthly"
      ((end_date.year * 12) + end_date.month) - ((@start_date.year * 12) + @start_date.month)
    else
      raise NoMethodError
    end
  end

  # returns true if this is a "good" date (ie, the beginning of the
  # week), or if it needs to be backed up further
  # NOTE: should be called is_first_thing? to make sense in this
  # context
  # this is pretty stupid, as it will require a lot of iterations for
  # nothing. but it works.
  def is_last_thing?(date)
    case @conditions[:breakdown_type]
    when "Weekly"
      date.strftime("%a") == "Mon"
    when "Quarterly"
      a = date.to_s.split("-")
      return [1,4,7,10].include?(a[1].to_i) && a[2] == "01"
    when "Daily"
      true
    when "Yearly"
      date.day == 1 && date.month == 1
    when "Monthly"
      date.day == 1
    else
      raise NoMethodError
    end
  end

  # get the date object for number "breakdowns" after the start date
  # return nil if you want that breakdown to be ignored (for example,
  # ignoring weekends on daily breakdown)
  def get_this_one(number)
    case @conditions[:breakdown_type]
    when "Weekly"
      @start_date + (7*number)
    when "Quarterly"
      d = @start_date.to_s.split("-").map{|x| x.to_i}
      number.times{|x|
        d = increase_arr(d)
      }
      Date.parse(d.map{|x| x.to_s}.join("-"))
    when "Daily w/weekends" # NOT ACTUALLY used.
      @start_date + number
    when "Daily"
      date = @start_date + number
      if [0,1].include?(date.wday) # MEEP. the hard coded sunday and monday are *HORRIBLE*
        return nil
      else
        return date
      end
    when "Yearly"
      Date.parse((@start_date.year + number).to_s + "-01-01")
    when "Monthly"
      month = @start_date.month
      year = @start_date.year
      month += number
      while month > 12
        year += 1
        month -= 12
      end
      Date.parse("#{year}-#{month}-01")
    else
      raise NoMethodError
    end
  end

  # takes in what x_axis_for outputted, and the date object of the
  # start date, and reformats it for the graph (as a number that will
  # be used to place it somewhere on the x axis)
  def graph_x_axis_for(x_axis, date)
    case @conditions[:breakdown_type]
    when "Quarterly"
      x_axis.match(/-Q(.)/)
      x_axis.sub(/-Q.$/, "." + (($1.to_i - 1) * 25).to_s)
    when "Weekly"
      date = Date.parse(x_axis.sub(/Week of /, ""))
      other_thing = (date.cweek / 52.0)
      if other_thing >= 1.0
        other_thing = 0.999
      end
      date.cwyear.to_s + "." + other_thing.to_s.gsub(/0\./, "")
    when "Daily"
      date.year + (date.yday / 365.0)
    when "Yearly"
      x_axis
    when "Monthly"
      (date.year * 12) + date.month
    else
      raise NoMethodError
    end
  end

  # get the last day in the range
  def second_timerange(first)
    case @conditions[:breakdown_type]
    when "Weekly"
      first + 6
    when "Quarterly"
      Date.parse(increase_arr(first.to_s.split("-").map{|x| x.to_i}).join("-")) - 1
    when "Daily"
      first
    when "Yearly"
      Date.parse(first.year.to_s + "-12-31")
    when "Monthly"
      month = first.month
      year = first.year
      month += 1
      if month > 12
        year += 1
        month -= 12
      end
      Date.parse("#{year}-#{month}-01") - 1
    else
      raise NoMethodError
    end
  end

  ##################
  # only if is_bar #
  ##################

  def extract_name_for_breakdown_type
    case @conditions[:breakdown_type]
    when "Day of week"
      return "DOW"
    when "Hour"
      return "hour"
    else
      raise NoMethodError
    end
  end

  def get_bar_list
    case @conditions[:breakdown_type]
    when "Day of week"
      v = 0..6
    when "Hour"
      v = 0..23
    else
      raise NoMethodError
    end
    return v.to_a
  end

  def check_date_for_extract_type(args, date)
    case args[:extract_type]
    when "DOW"
      return true if args[:extract_value] == date.cwday
    when "hour"
      return true
    else
      raise NoMethodError
    end
    return false
  end

  # calls a method specific to that report that takes args, explained
  # below, and returns a hash (one element for each line) with the key
  # being the name of the line and the value the number to be plotted
  # for that date range

  # anywhere in this file where you see a variable called args, it is a hash with these options:
  # :start_date - the first date to include
  # :end_date - the second date to inlcude
  # :extract_type - if also limiting by day of week, hour, etc, this will be not nil, so extract this and make sure it's equal to :extract_value
  # :extract_value - the value to make sure that the thing extracted from the date matches
  # :number_of_days - the numbef of days matching these criteria (for averaging, etc)
#  def get_thing_for_timerange(args)
#    set_conditions(params[:conditions]) # what's this?
#    get_for_timerange(args)
#  end

  ######################
  # Random helper crap #
  ######################

  attr_accessor :broken_down_by, :x_axis, :data, :table_x_axis, :full_title, :graph_titles, :display

  def generate_report_data
    list = []
    @start_date = Date.parse(@conditions[:start_date])
    end_date = Date.parse(@conditions[:end_date])
    if is_line
      @start_date = back_up_to_last_thing(@start_date)
      end_date = back_up_to_last_thing(end_date)
    elsif is_bar
    else
      raise NoMethodError
    end
    if is_line
      (number_between_them(end_date) + 1).times{|x|
        list << get_this_one(x)
      }
    elsif is_bar
      list = get_bar_list.to_a
    else
      raise NoMethodError
    end
    list.delete_if{|x| x.nil?}
    @broken_down_by = @conditions[:breakdown_type].downcase.sub(/ly$/, "").sub(/i$/, "y")
    @full_title = self.title + " (broken down by #{@broken_down_by})"
    cstr = self.conditions_to_s()
    @full_title = @full_title + " (" + cstr + ")" if cstr.length > 0
    @x_axis = []
    list.each{|x|
      @x_axis << x_axis_for(x)
    }
    @graph_x_axis = []
    @table_x_axis = {}
    @x_axis.each_with_index{|x,i|
      if is_line
        @graph_x_axis << graph_x_axis_for(x, list[i])
      elsif is_bar
        @graph_x_axis << list[i]
      else
        raise NoMethodError
      end
      if is_line
        @table_x_axis[x] = list[i].to_s
      elsif is_bar
        @table_x_axis[x] = @x_axis[i]
      else
        raise NoMethodError
      end
    }
    if is_line
      list.map!{|x|
        {:start_date => x.to_s, :end_date => second_timerange(x).to_s}
      }
    elsif is_bar
      list.map!{|x|
        {:start_date => @start_date.to_s, :end_date => end_date.to_s, :extract_type => extract_name_for_breakdown_type, :extract_value => x}
      }
    else
      raise NoMethodError
    end
    list.each{|args|
      if is_line
        args[:number_of_days] = (Date.strptime(args[:end_date]) - Date.strptime(args[:start_date])).ceil
      elsif is_bar
        args[:number_of_days] = 0
        array_of_dates(args[:start_date], args[:end_date]).each do |date|
          args[:number_of_days] += 1 if check_date_for_extract_type(args, date)
        end
      else
        raise NoMethodError
      end
    }
    generate_display_data(list)
  end

  # for single reports
  def generate_display_data(argslist)
    @data = []
    @graph_titles = []
    @data[0] = {}
    @graph_titles[0] = self.title
    resultlist = argslist.map{|args|
      get_for_timerange(args)
    }
    lines = resultlist.map{|x| x.keys}.flatten.uniq
    lines.each{|x|
      @data[0][x] = []
    }
    resultlist.each{|thing|
      lines.each{|k|
        v = thing[k]
        v = 0 if v.nil?
        @data[0][k] << v
      }
    }
    @display = [["graph", 0], ["table", 0]]
  end

  def array_of_dates(start, stop)
    start = Date.parse(start) if start.class == String
    stop = Date.parse(stop) if stop.class == String
    if start > stop
      temp = start
      start = stop
      stop = temp
    end
    stop += 1
    arr = []
    i = start
    while i != stop
      arr << i
      i = i + 1
    end
    return arr
  end

  def breakdown_types
    line_breakdown_types + bar_breakdown_types
  end

  def is_line
    line_breakdown_types.include?(@conditions[:breakdown_type])
  end

  def is_bar
    bar_breakdown_types.include?(@conditions[:breakdown_type])
  end

  def back_up_to_last_thing(date)
    temp = date
    until is_last_thing?(temp)
      temp = temp - 1
    end
    return temp
  end

  # used for quarterly
  def increase_arr(d)
    d[1] += 3
    if d[1] > 12
      d[1] = 1
      d[0] += 1
    end
    d
  end

    def created_at_conditions_for_report(args)
      conditions_with_daterange_for_report(args, "created_at")
    end

    def occurred_at_conditions_for_report(args)
      conditions_with_daterange_for_report(args, "occurred_at")
    end

    def conditions_with_daterange_for_report(args, field)
      h = {"#{field}_enabled" => "true", "#{field}_date_type" => "arbitrary", "#{field}_start_date" => args[:start_date], "#{field}_end_date" => args[:end_date], "#{field}_enabled" => "true"}
      conditions_for_report(args, field, h)
    end

    def set_conditions(conds)
      @conditions = conds
    end

    def conditions_to_s
      c = Conditions.new
      c.apply_conditions(usable_conditions)
      return c.skedj_to_s("before")
    end

    def sql_for_report(model, conditions)
      c = Conditions.new
      c.apply_conditions(conditions)
      return DB.prepare_sql(c.conditions(model))
    end

    def conditions_for_report(args, field, extra_conditions = {})
      h = extra_conditions
      if args[:extract_type]
        h["extract_enabled"] = "true"
        h["extract_type"] = args[:extract_type]
        h["extract_value"] = args[:extract_value]
        h["extract_field"] = field
      end
      h["empty_enabled"] = "true"
      return usable_conditions.merge(h)
    end

    def usable_conditions
      @conditions.dup.delete_if{|k,v| [:start_date, :end_date, :report_type, :breakdown_type].map{|x| x.to_s}.include?(k)}
    end

    def call_income_report(args)
      r = ReportsController.new
      r.income_report(created_at_conditions_for_report(args))
    end

    def find_all_donations(args)
      c = Conditions.new
      c.apply_conditions(created_at_conditions_for_report(args))
      n = Donation.number_by_conditions(c)
    end

    def breakdown_types # default
      line_breakdown_types + bar_breakdown_types
    end

    # line breakdown types are when the whole date range is chunked up
    # based on something
    def line_breakdown_types
      ["Yearly", "Quarterly", "Monthly", "Weekly", "Daily"]
    end

    # bar breakdown types are when you want to compare things like
    # "which day of the week has the highest average" and such
    def bar_breakdown_types
      ["Day of week", "Hour"]
    end

    def category # default
      "Other"
    end

    def title
      "Report of " + self.name
    end

    def valid_conditions # default
      []
    end

  def child_report_for_argslist(report, argslist)
    r = report.new
    r.set_conditions(@conditions)
    r.generate_display_data(argslist)
    return r # manipulate its .data, etc
  end

  class << self
    def name
      self.to_s.sub("Trend", "").underscore.humanize.split(" ").map{|x| x.capitalize}.join(" ").singularize
    end

    def find_class(name)
      found = all_reports.select{|x| x.name == name}
      raise "Cannot find class named #{((name.underscore.parameterize.tableize + "_trend").classify.to_s)}" if found.length != 1
      return found.first
    end

    def all_reports
      self.send(:subclasses).map{|x| x.constantize}
    end

    def all_report_types
      return all_reports.map{|x| x.name}
    end

    def valid_conditions
      self.new.valid_conditions
    end

    def title
      self.new.title
    end

    def breakdown_types
      self.new.breakdown_types
    end

    def category
      self.new.category
    end
  end
end

class AverageFrontdeskIncomesTrend < TrendReport
    def category
      "Transaction"
    end

    def title
      "Report of Average Income at Front Desk"
    end

    def get_for_timerange(args)
      thing = call_income_report(args)
      thing = thing[:donations]["register total"] # WHY IS THERE A SPACE!?!?!
      suggested = thing["suggested"][:total] / 100.0
      fees = thing["fees"][:total] / 100.0
      number = find_all_donations(args)
      total = suggested + fees
      suggested = suggested / number
      fees = fees / number
      total = total / number
      suggested = 0.0 if suggested.nan?
      fees = 0.0 if fees.nan?
      total = 0.0 if total.nan?
      suggested = sprintf("%.2f", suggested).to_f
      fees = sprintf("%.2f", fees).to_f
      total = sprintf("%.2f", total).to_f
      {:fees => fees, :suggested => suggested, :total => total}
    end

    def valid_conditions
      ["cashier_created_by"]
    end
end
class AverageSaleIncomesTrend < TrendReport
    def category
      "Transaction"
    end

    def title
      "Report of Average Income for Sales"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( reported_amount_due_cents )/(100.0*COUNT(*)) AS amount
  FROM sales WHERE " + sql_for_report(Sale, created_at_conditions_for_report(args)))
      return {:total => res.first["amount"]}
  end
end
class IncomesTrend < TrendReport
    def category
      "Income"
    end

    def get_for_timerange(args)
      thing = call_income_report(args)[:grand_totals]["total"]["total"][:total] / 100.0
      {:income => thing}
    end
    def title
      "Income report"
    end
end
class ActiveVolunteersTrend < TrendReport
    def category
      "Volunteer"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT count( distinct contact_id ) as vol_count
    FROM volunteer_tasks
    WHERE contact_id IN (
    SELECT xxx.contact_id
      FROM volunteer_tasks AS xxx
      WHERE xxx.date_performed BETWEEN
        ?::date AND ?::date
      GROUP BY xxx.contact_id
      HAVING SUM(xxx.duration) > #{Default['hours_for_discount'].to_f}) AND #{sql_for_report(VolunteerTask, conditions_for_report(args, "date_performed"))};", Date.strptime(args[:start_date]) - Default['days_for_discount'].to_f, args[:start_date])
      final = 0
      if res.first
        final = res.first['vol_count']
      end
      return {:active => final}
    end
    def title
      "Report of Number of Active Volunteers"
    end

    def breakdown_types
      line_breakdown_types
    end
end
class MasterGizmoFlowTrend < TrendReport
  def category
    "Combined"
  end

  # for single reports
  def generate_display_data(argslist)
    @data = []
    @graph_titles = []

    donations = child_report_for_argslist(DonationsGizmoCountByTypesTrend, argslist)
    sales = child_report_for_argslist(SalesGizmoCountByTypesTrend, argslist)
    disbursements = child_report_for_argslist(DisbursementGizmoCountByTypesTrend, argslist)
    recyclings = child_report_for_argslist(RecycledGizmoCountByTypesTrend, argslist)
    returns = child_report_for_argslist(ReturnGizmoCountByTypesTrend, argslist)

    dis_tot = []
    disbursements.data[0].values.each{|a|
      a.each_with_index{|x,i|
        dis_tot[i] ||= 0
        dis_tot[i] += x.to_i
      }
    }

    @data[0] = {}
    @data[0][:sold] = sales.data[0][:count]
    @data[0][:donated] = donations.data[0][:count]
    @data[0][:recycled] = recyclings.data[0][:count]
    @data[0][:returned] = returns.data[0][:count]
    @data[0][:disbursed] = dis_tot

    reuse_tot = []
    for a in [@data[0][:sold], @data[0][:disbursed]]
      a.each_with_index{|x,i|
        reuse_tot[i] ||= 0
        reuse_tot[i] += x.to_i
      }
    end
    @data[0][:reused] = reuse_tot
    @graph_titles[0] = self.title

    @data[1] = disbursements.data[0]
    @graph_titles[1] = disbursements.graph_titles[0]

    @data[2] = {}
    @data[2][:recycled] = @data[0][:recycled]
    @data[2][:reused] = @data[0][:reused]
    @graph_titles[2] = "Recycle vs Reuse"

    @data[3] = {}
    @data[3][:reused] = @data[0][:reused]
    @data[3][:returned] = @data[0][:returned]
    @data[3][:return_percentage] = []
    argslist.length.times do |i|
      @data[3][:return_percentage][i] = 100 * (@data[3][:returned][i].to_f / @data[3][:reused][i].to_f)
    end
    @data[4] = {}
    @data[4][:return_rate] = @data[3][:return_percentage]
    @graph_titles[4] = "Return Rate"

    @data[5] = {}
    @data[5][:donated] = @data[0][:donated]
    @data[5][:reused] = @data[0][:reused]
    @data[5][:disbursed] = @data[0][:disbursed]
    @data[5][:sold] = @data[0][:sold]
    for i in [:reuse_percentage, :disbursement_percentage, :sales_percentage]
      @data[5][i] = []
    end
    argslist.length.times do |i|
      divisor = @data[5][:donated][i].to_f
      if divisor == 0.0
        @data[5][:reuse_percentage][i] = @data[5][:disbursement_percentage][i] = @data[5][:sales_percentage][i] = 0
      else
        @data[5][:reuse_percentage][i] = 100 * (@data[5][:reused][i].to_f / divisor)
        @data[5][:disbursement_percentage][i] = 100 * (@data[5][:disbursed][i].to_f / divisor)
        @data[5][:sales_percentage][i] = 100 * (@data[5][:sold][i].to_f / divisor)
      end
    end
    @data[6] = {:reuse_percentage => @data[5][:reuse_percentage]}
    @data[7] = {:disbursement_percentage => @data[5][:disbursement_percentage]}
    @data[8] = {:sales_percentage => @data[5][:sales_percentage]}
    @graph_titles[6] = "Reuse Rate"
    @graph_titles[7] = "Disbursement Rate"
    @graph_titles[8] = "Sales Rate"

    @data[9] = {}
    sales_totals = child_report_for_argslist(SalesAmountByGizmoTypesTrend, argslist)
    @data[9][:sales] = sales_totals.data[0][:amount]
    @data[9][:sold] = @data[0][:sold]
    @data[9][:avg_price] = []
    argslist.length.times do |i|
      divisor = @data[9][:sold][i].to_f
      if divisor == 0.0
        @data[9][:avg_price][i] = 0.0
      else
        @data[9][:avg_price][i] = @data[9][:sales][i].to_f / divisor
      end
    end
    @data[10] = {:sales => @data[9][:sales]}
    @data[11] = {:sold => @data[9][:sold]}
    @data[12] = {:avg_price => @data[9][:avg_price]}
    @graph_titles[10] = "Total Sales Amount"
    @graph_titles[11] = "Sales Count"
    @graph_titles[12] = "Average Sale Price"

    @display = [["graph", 0], ["table", 0], ["graph", 1], ["table", 1], ["graph", 10], ["graph", 11], ["graph", 12], ["table", 9], ["graph", 2], ["table", 2], ["graph", 4], ["table", 3], ["graph", 6], ["graph", 7], ["graph", 8], ["table", 5]]
  end

  def valid_conditions
    ["gizmo_category_id", "gizmo_type_id"]
  end

  def title
    "Master Gizmo Flow Report"
  end
end
class SalesTotalsTrend < TrendReport
    def category
      "Income"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( reported_amount_due_cents )/100.0 AS amount
  FROM sales WHERE " + sql_for_report(Sale, created_at_conditions_for_report(args)))
      return {:total => res.first["amount"]}
    end

    def title
      "Report of total sales in dollars"
    end
end
class DonationTotalsTrend < TrendReport
    def category
      "Income"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( amount_cents )/100.0 AS amount
  FROM payments JOIN donations ON payments.donation_id = donations.id WHERE " + sql_for_report(Donation, created_at_conditions_for_report(args)))
      return {:total => res.first["amount"]}
    end

    def title
      "Report of total donations in dollars"
    end
end
class DonationsCountsTrend < TrendReport
    def category
      "Transaction"
    end

    def get_for_timerange(args)
      return {:count => find_all_donations(args).to_s}
    end

    def title
      "Report of number of donations"
    end
end
class VolunteerHoursByProgramsTrend < TrendReport
    def category
      "Volunteer"
    end

    def get_for_timerange(args)
      where_clause = sql_for_report(VolunteerTask, conditions_with_daterange_for_report(args, "date_performed"))
      res = DB.execute("SELECT programs.description, SUM( duration )
  FROM volunteer_tasks
  LEFT JOIN programs ON volunteer_tasks.program_id = programs.id
  WHERE #{where_clause}
  AND programs.volunteer = 't'
  GROUP BY programs.id, programs.description
  ORDER BY programs.description;")
      Hash[*res.to_a.collect{|x| [x["description"], x["sum"]]}.flatten]
    end

    def title
      "Report of volunteer hours by program"
    end
    def breakdown_types
      super - ["Hour"]
    end
end
class DonationsGizmoCountByTypesTrend < TrendReport
    def category
      "Gizmo"
    end

    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Count of gizmos donated by type"
    end
    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( gizmo_count ) AS count
FROM gizmo_events
WHERE donation_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}")
      return {:count => res.first["count"]}
    end
end

class DisbursementGizmoCountByTypesTrend < TrendReport
    def category
      "Gizmo"
    end

    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Count of gizmos disbursed by type"
    end
    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( gizmo_count ) AS count, disbursement_types.description AS desc
FROM gizmo_events
JOIN disbursements ON gizmo_events.disbursement_id = disbursements.id
JOIN disbursement_types ON disbursements.disbursement_type_id = disbursement_types.id
WHERE disbursement_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}
GROUP BY 2;")
      ret = {}
      res.each{|x|
        ret[x["desc"]] = x["count"]
      }
      return ret
  end
end

class RecycledGizmoCountByTypesTrend < TrendReport
    def category
      "Gizmo"
    end

    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Count of gizmos recycled by type"
    end
    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( gizmo_count ) AS count
FROM gizmo_events
WHERE recycling_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}")
      return {:count => res.first["count"]}
    end
end

class ReturnGizmoCountByTypesTrend < TrendReport
    def category
      "Gizmo"
    end

    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Count of gizmos returned by type"
    end
    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( gizmo_count ) AS count
FROM gizmo_events
WHERE gizmo_return_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}")
      return {:count => res.first["count"]}
    end
end

class SalesGizmoCountByTypesTrend < TrendReport
    def category
      "Gizmo"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( gizmo_count ) AS count
FROM gizmo_events
WHERE sale_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}")
      return {:count => res.first["count"]}
    end

    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Count of gizmos sold by type"
    end
end
class SalesAmountByGizmoTypesTrend < TrendReport
    def category
      "Income"
    end

    def get_for_timerange(args)
      res = DB.execute("SELECT SUM( unit_price_cents * gizmo_count )/100.0 AS due
FROM gizmo_events
WHERE sale_id IS NOT NULL
AND #{sql_for_report(GizmoEvent, occurred_at_conditions_for_report(args))}")
      return {:amount => res.first["due"]}
    end
    def valid_conditions
      ["gizmo_category_id", "gizmo_type_id"]
    end
    def title
      "Sales amount by gizmo type"
  end
end
class NumberOfSalesByCashiersTrend < TrendReport
    def category
      "Transaction"
    end

    def title
      "Number of sales by Cashier"
    end
    def get_for_timerange(args)
      where_clause = sql_for_report(Sale, conditions_with_daterange_for_report(args, "created_at"))
      res = DB.execute("SELECT count(*), users.login FROM sales
 LEFT JOIN users ON users.id = sales.cashier_created_by
 WHERE #{where_clause}
 GROUP BY users.login
 ORDER BY users.login")
      Hash[*res.to_a.collect{|x| [x["login"], x["count"]]}.flatten]
    end

end
class TotalAmountOfSalesByCashiersTrend < TrendReport
    def category
      "Income"
    end

    def title
      "Total amount of sales by cashier"
    end
    def get_for_timerange(args)
      where_clause = sql_for_report(Sale, conditions_with_daterange_for_report(args, "created_at"))
      res = DB.execute("SELECT users.login, SUM(payments.amount_cents) FROM payments INNER JOIN sales ON payments.sale_id = sales.id LEFT JOIN users ON users.id = sales.cashier_created_by WHERE #{where_clause} GROUP BY 1;")
      Hash[*res.to_a.collect{|x| [x["login"], x["sum"].to_i / 100.0]}.flatten]
    end
end
class NumberOfHoursWorkedByWorkersTrend < TrendReport
    def get_for_timerange(args)
      where_clause = sql_for_report(WorkedShift, conditions_with_daterange_for_report(args, "date_performed"))
      res = DB.execute("SELECT workers.name, SUM( duration )
  FROM worked_shifts
  LEFT JOIN workers ON worked_shifts.worker_id = workers.id
  WHERE #{where_clause}
  GROUP BY workers.name
  ORDER BY workers.name;")
      Hash[*res.to_a.collect{|x| [x["name"], x["sum"]]}.flatten]
    end
    def category
      "Staff"
    end
    def title
      "Report of hours worked by worker"
    end
    def valid_conditions
      ["job"]
    end
end
