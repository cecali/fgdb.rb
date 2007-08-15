class Contact < ActiveRecord::Base
  has_and_belongs_to_many :contact_types
  has_many :contact_methods
  has_many :contact_method_types, :through => :contact_methods

  has_many :donations
  has_many :volunteer_tasks, :order => 'start_time DESC'

  # acts_as_userstamp

  validates_presence_of :postal_code
  before_save :remove_empty_contact_methods

  def is_organization?
    self.is_organization
  end

  def is_person?
    ! self.is_organization?
  end

  def uncompleted
    vt = volunteer_tasks.find_by_duration(nil)
    if not vt.nil? and vt.start_time < 1.day.ago
      # evidentally they forgot to check out... make a new handler for this later.
      vt.destroy
      return nil
    else
      return vt
    end
  end

  def checked_in?
    not uncompleted.nil?
  end

  def check(options = {})
    if checked_in?
      task = uncompleted
      # since multiparameter attributes won't work w/ aliases, do it manually
      time_attrs = []
      for i in 1..5
        time_attrs << options.delete("end_time(#{i}i)").to_i
      end
      options[:end_time] = Time.local(*time_attrs)
      task.update_attributes(options)
    else
      task = VolunteerTask.new(options)
      volunteer_tasks << task
      task.save
    end
    return task
  end

  def hours_actual(last_ninety = false)
    tasks = last_ninety ? last_ninety_days_of_volunteer_tasks : volunteer_tasks
    tasks.inject(0.0) do |total,task|
      total += task.duration
    end
  end

  def find_volunteer_tasks(cutoff = nil)
    # if it's named volunteer_tasks it breaks everything
    if cutoff
      conditions = [ "contact_id = ? AND date_performed >= ?", id, cutoff ]
    else
      conditions = [ "contact_id = ?", id ]
    end
    VolunteerTask.find(:all,
                       :conditions => conditions)
  end

  def hours_effective
    volunteer_tasks(Date.today - 365).inject(0.0) do |total,task|
      unless task.type_of_task?('build')
        total += task.effective_duration
      end
      total
    end
  end

  def last_ninety_days_of_volunteer_tasks
    volunteer_tasks(Date.today - 90)
  end

  def last_ninety_days_of_actual_hours
    hours_actual(true)
  end

  def last_few_volunteer_tasks
    volunteer_tasks.sort_by {|v_t| v_t.date_performed }[-3..-1]
  end

  def default_volunteer_task_type
    last_few = last_few_volunteer_tasks
    if( last_few.length > 1 and
          last_few.map {|v_t| v_t.volunteer_task_type}.uniq.length == 1 )
      return last_few.first.volunteer_task_type
    else
      return []
    end
  end

  def to_s
    display_name
  end

  def screen_sortby
    display_name
  end

  def display_name
    if is_person?
      if(self.first_name || self.middle_name || self.surname)
        "%s %s %s" % [self.first_name, self.middle_name, self.surname]
      else
        '(person without name)'
      end
    else
      if self.organization && ! self.organization.empty?
        self.organization
      else
        '(organization without name)'
      end
    end
  end

  def csz
    "#{city}, #{state_or_province}  #{postal_code}"
  end

  def display_name_address
    disp = []
    disp.concat(display_name.to_a) unless
      display_name.nil? or display_name.size == 0
    disp.concat(display_address.to_a) unless 
      display_address.nil? or display_address.size == 0
    return disp
  end

  def display_address
    dispaddr = []
    dispaddr.push(address)
    dispaddr.push(extra_address) unless 
      extra_address.nil? or extra_address == ''
    dispaddr.push(csz)
    dispaddr.push(country) unless 
      country.nil? or country == '' or country.upcase =~ /^USA*$/
    return dispaddr
  end

  def types
    contact_types.join(' ')
  end

  def last_donation
    #:MC: optimize this into sql
    donations.sort_by {|don| don.created_at}.last
  end

  def default_discount_schedule
    #:MC: i should move this business logic out to the database itself
    #(order, condition)
    if last_ninety_days_of_actual_hours >= 4.0
      DiscountSchedule.volunteer
    #elsif last_donation.created_at.to_date == Date.today
    #  DiscountSchedule.same_day_donor
    else
      DiscountSchedule.no_discount
    end
  end

  private

    def remove_empty_contact_methods
      for contact_method in contact_methods
        if contact_method.description.nil? or contact_method.description.empty?
          contact_method.destroy
        end
      end
    end

  class << self

    def people
      find(:all, :conditions => ["is_organization = ?", false])
    end

    def volunteers
      find_by_type('volunteer')
    end

    def find_by_type(type)
      sql = "SELECT contacts.* FROM contacts
                 LEFT JOIN contact_types_contacts AS j ON j.contact_id = contacts.id
                 LEFT JOIN contact_types AS c_t ON j.contact_type_id = c_t.id
               WHERE c_t.description = ? "
      find_by_sql([sql, type])
    end

    def organizations
      find(:all, :conditions => ["is_organization = ?", true])
    end

    def search(query, options = {})
      # if the user added query wildcards or search metaterms, leave
      # be if not, assume it's better to bracket each word with
      # wildcards and join with ANDs.
      query = prepare_query(query)
      find_by_contents( query, options )
    end

    def search_by_type(type, query, options = {})
      if query.to_i.to_s == query
        # allow searches by id
        search(query, options)
      else
        query = prepare_query(query)
        query += " AND types:\"*#{type}*\""
        search(query, options)
      end
    end

    protected

    def prepare_query(q)
      unless q =~ /\*|\~| AND| OR/
        q = q.split.map do |word|
          "*#{word}*" 
        end.join(' AND ')
      end
      q
    end

    end # class << self

  acts_as_ferret :fields => {
    'first_name' => {:boost => 2},
    'middle_name' => {},
    'surname' => {:boost => 2.5},
    'organization' => {:boost => 2},
    'types' => {:boost => 0}
  }

end
