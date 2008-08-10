class VolunteerTask < ActiveRecord::Base
  acts_as_userstamp

  belongs_to :volunteer_task_type
  belongs_to :contact
  belongs_to :community_service_type

  validates_presence_of :contact
  validates_presence_of :volunteer_task_type
  validates_presence_of :date_performed
  validates_presence_of :duration

  before_save :add_contact_types

  def self.find_by_conditions(conditions)
    connection.execute("SELECT volunteer_tasks.duration AS duration, community_service_types.description AS community_service_type, volunteer_task_types.description AS volunteer_task_types FROM volunteer_tasks LEFT OUTER JOIN volunteer_task_types ON volunteer_task_types.id = volunteer_tasks.volunteer_task_type_id LEFT OUTER JOIN community_service_types ON community_service_types.id = volunteer_tasks.community_service_type_id WHERE #{sanitize_sql_for_conditions(conditions)}")
  end

  def validate
    if contact.nil?
      errors.add(:contact_id, "must be choosen")
    end
    if duration.to_f <= 0.0
      errors.add(:duration, "must be greater than zero")
    end
  end

  def effective_duration
    if volunteer_task_type
      return (duration * volunteer_task_type.hours_multiplier)
    else
      return duration
    end
  end

  def type_of_task?(type)
    volunteer_task_type.type_of_task? type
  end

  def add_contact_types
    # automatically make the person who did this a volunteer
    # the following is commented out because only
    # volunteers can be searched for... but non-volunteers
    # can become volunteers, can't they? See ticket #234
    required = [ContactType.find_by_description("volunteer")] # volunteer
    if type_of_task?('build')
      required << ContactType.find_by_description("build") # builder
    elsif type_of_task?('adoption')
      required << ContactType.find_by_description("adopter") # adopter
    end
    for type in required
      unless contact.contact_types.include?(type)
        contact.contact_types << type
      end
    end
  end
end
