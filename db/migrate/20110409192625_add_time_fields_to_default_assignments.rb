class AddTimeFieldsToDefaultAssignments < ActiveRecord::Migration
  def self.up
    add_column :default_assignments, :start_time, :time
    add_column :default_assignments, :end_time, :time
    add_column :default_assignments, :slot_number, :integer
    DefaultAssignment.find(:all).each{|x|
      x.start_time = x.volunteer_default_shift.start_time
      x.end_time = x.volunteer_default_shift.end_time
      x.slot_number = 1
      x.save!
      i = 2
      (x.volunteer_default_shift.slot_count - 1).times do
        y = DefaultAssignment.new
        y.volunteer_default_shift_id = x.volunteer_default_shift_id
        y.start_time = x.volunteer_default_shift.start_time
        y.end_time = x.volunteer_default_shift.end_time
        y.slot_number = i
        y.contact_id = x.contact_id
        y.save!
        i += 1
      end
    }
    VolunteerDefaultShift.find(:all).each{|x| x.fill_in_available}
    VolunteerDefaultEvent.find(:all).each{|x|
      x.merge_similar_shifts
    }
    VolunteerEvent.find(:all).each{|x|
      x.merge_similar_shifts
    }
  end

  def self.down
    remove_column :default_assignments, :start_time
    remove_column :default_assignments, :end_time
    remove_column :default_assignments, :slot_number
  end
end
