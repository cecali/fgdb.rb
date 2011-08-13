class Holiday < ActiveRecord::Base
  belongs_to :weekday
  belongs_to :schedule
  belongs_to :frequency_type

  def Holiday.is_holiday?(day)
    !! Holiday.find(:first, :conditions => ["holiday_date = ? AND is_all_day = 't'", day])
  end

  def Holiday.add_credit_for_holidays_to_calendar(calendar,worker)
    calendar.add_for_day{|x| Holiday.is_holiday?(x) ? worker.holiday_credit_per_day(x.holiday_date) : 0}
  end
end
