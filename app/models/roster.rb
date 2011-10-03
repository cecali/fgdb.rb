class Roster < ActiveRecord::Base
  has_and_belongs_to_many :skeds

  def skeds_s
    self.skeds.map(&:name).sort.join(", ")
  end

  def vol_event_for_date(date)
    VolunteerEvent.find_or_create_by_description_and_date("Roster ##{self.id}", date)
  end

  def vol_event_for_weekday(wday)
    VolunteerDefaultEvent.find_or_create_by_description_and_weekday_id("Roster ##{self.id}", wday)
  end
end
