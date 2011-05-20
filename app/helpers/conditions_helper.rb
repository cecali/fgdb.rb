module ConditionsHelper
  include ConditionsBaseHelper

  private

  def html_for_assigned_condition(params_key)
    check_box params_key, "assigned"
  end

  def html_for_needs_checkin_condition(params_key)
    ""
  end

  def html_for_cancelled_condition(params_key)
    "Show cancelled: " + check_box(params_key, "cancelled")
  end

  def html_for_schedule_condition(params_key)
    which_way = (params[params_key] ? params[params_key][:schedule_which_way] : nil) || 'Family'
    if !['Family', 'Solo', 'Solo + root'].include?(which_way)
      which_way = 'Family'
    end
    ((select params_key, :schedule_id, Schedule.find(:all, :order => "lft").collect {|c| [c.full_name, c.id] }) +
    (radio_button params_key, :schedule_which_way, 'Family', :checked => (which_way=='Family')) + "Family" +
    (radio_button params_key, :schedule_which_way, 'Solo', :checked => (which_way=='Solo')) + "Solo" +
    (radio_button params_key, :schedule_which_way, 'Solo + root', :checked => (which_way=='Solo + root')) + "Solo + root")
  end

  def html_for_worker_condition(params_key)
    select(params_key, "worker_id", Worker.real_people.sort_by(&:name).collect {|p| [ p.name, p.id ] })
  end

  def html_for_job_condition(params_key)
    select(params_key, "job_id", Job.find(:all).sort_by(&:description).collect {|p| [ p.description, p.id ] })
  end

  def html_for_attendance_type_condition(params_key)
    select(params_key, "attendance_type_id", AttendanceType.find(:all).sort_by(&:name).collect {|p| [ p.name, p.id ] })
  end

  def html_for_weekday_condition(params_key)
    select(params_key, "weekday_id", Weekday.find(:all).sort_by(&:id).collect{|p| [p.name, p.id]})
  end

  def html_for_roster_condition(params_key)
    select(params_key, "roster_id", Roster.find(:all).sort_by(&:name).collect{|p| [ p.name, p.id ]})
  end

  def html_for_sked_condition(params_key)
    select(params_key, "sked_id", Sked.find(:all).sort_by(&:name).collect{|p| [ p.name, p.id ]})
  end

  def html_for_volunteer_task_type_condition(params_key)
    select(params_key, "volunteer_task_type_id", VolunteerTaskType.find(:all).sort_by(&:name).collect {|p| [ p.description, p.id ] })
  end

  def html_for_can_login_condition(params_key)
    ""
  end

  def html_for_empty_condition(params_key)
    ""
  end

  def html_for_contribution_condition(params_key)
    ""
  end

  def html_for_role_condition(params_key)
    collection_select(params_key, "role", Role.find(:all), "id", "name")
  end

  def html_for_action_condition(params_key)
    collection_select(params_key, "action", Action.find(:all), "id", "description")
  end

  def html_for_type_condition(params_key)
    collection_select(params_key, "type", Type.find(:all), "id", "description")
  end

  def html_for_id_condition(params_key)
    text_field(params_key, 'id')
  end

  def html_for_serial_number_condition(params_key)
    text_field(params_key, 'serial_number')
  end

  def html_for_contact_type_condition(params_key)
    collection_select(params_key, "contact_type", ContactType.find(:all), "id", "description")
  end

  def html_for_needs_attention_condition(params_key)
    ""
  end

  def html_for_anonymous_condition(params_key)
    ""
  end

  def html_for_unresolved_invoices_condition(params_key)
    ""
  end

  def html_for_payment_method_condition(params_key)
    render( :partial => 'transaction/payment_method_select',
            :locals => {:field_id_prefix => params_key,
              :field_name_prefix => params_key,
              :hide_empty => true,
              :show_label => false,
              :paid_object => eval("@" + params_key)} )
  end

  def html_for_payment_amount_condition(params_key)
    select_visibility(
                      params_key,
                      'payment_amount_type',
                      [['exact', text_field(params_key, 'payment_amount_exact')],
                       ['between', "%s to %s" % [text_field(params_key, 'payment_amount_low'),
                                                 text_field(params_key, 'payment_amount_high')]],
                       ['>=', text_field(params_key, 'payment_amount_ge')],
                       ['<=', text_field(params_key, 'payment_amount_le')],
                      ])
  end

  def html_for_gizmo_type_id_condition(params_key)
    select(params_key, 'gizmo_type_id', GizmoType.find(:all).sort_by(&:description).collect(){|x|[x.description, x.id]})
  end

  def html_for_gizmo_category_id_condition(params_key)
    select(params_key, 'gizmo_category_id', GizmoCategory.find(:all).sort_by(&:description).collect(){|x|[x.description, x.id]})
  end

  def html_for_disbursement_type_id_condition(params_key)
    select(params_key, 'disbursement_type_id', DisbursementType.find(:all).sort_by(&:description).collect(){|x|[x.description, x.id]})
  end

  def html_for_store_credit_id_condition(params_key)
    text_field(params_key, 'store_credit_id')
  end

  def html_for_covered_condition(params_key)
    check_box(params_key, 'covered')
  end

  def html_for_postal_code_condition(params_key)
    text_field(params_key, 'postal_code')
  end

  def html_for_city_condition(params_key)
    text_field(params_key, 'city')
  end

  def html_for_phone_number_condition(params_key)
    text_field(params_key, 'phone_number')
  end

  def html_for_organization_condition(params_key)
    check_box(params_key,"is_organization")
  end

  def html_for_contact_condition(params_key)
    if has_required_privileges('/contact_condition_everybody')
      contact_field('@' + params_key, 'contact_id',
                    :locals => {:options =>
                      {
                        :object_name => params_key,
                        :field_name => 'contact_id',
                        :element_prefix => 'filter_contact',
                        :display_edit => false,
                        :display_create => false,
                        :show_label => false,
                      },
                      :contact => eval("@" + params_key).contact
                    } )
    elsif has_privileges("has_contact")
      "Me" + hidden_field(params_key, 'contact_id', :value => @current_user.contact_id)
    else
      raise
    end
  end

  def html_for_volunteer_hours_condition(params_key)
    select_visibility(
                      params_key,
                      'volunteer_hours_type',
                      [['exact', text_field(params_key, 'volunteer_hours_exact')],
                       ['between', "%s to %s" % [text_field(params_key, 'volunteer_hours_low'),
                                                 text_field(params_key, 'volunteer_hours_high')]],
                       ['>=', text_field(params_key, 'volunteer_hours_ge')],
                       ['<=', text_field(params_key, 'volunteer_hours_le')],
                      ])
  end

  def html_for_email_condition(params_key)
    text_field(params_key, 'email')
  end

  def html_for_flagged_condition(params_key)
    ""
  end

  def html_for_system_condition(params_key)
    text_field(params_key, 'system_id')
  end

  def html_for_contract_condition(params_key)
    collection_select(params_key, "contract_id", Contract.usable, "id", "description")
  end

  def html_for_created_by_condition(params_key)
    collection_select(params_key, "created_by", [User.new, User.find(:all)].flatten, "id", "login")
  end

  def html_for_cashier_created_by_condition(params_key)
    collection_select(params_key, "cashier_created_by", [User.new, User.find(:all)].flatten, "id", "login")
  end
end
