module SidebarHelper
  # TODO: add methods like this that control it for all 4 transactions + hours, reports, and contact dedup
  # TODO: get this from some table or something

  def should_show_library
    true
  end

  def should_show_fgss
    true
  end

  def should_show_schedule
    true
  end

  def should_show_edit_schedule
    true
  end

  def controller_to_section
    {"recyclings" => "recyclings",
    "volunteer_tasks" => "hours",
    "sales" => "sales",
    "donations" => "donations",
    "disbursements" => "disbursements",
    "reports" => "reports",
    "graphic_reports" => "reports",
    "work_shifts" => "staff schedule",
    "contacts" => "contacts",
    "contact_duplicates" => "contacts",
#    "library" => "library",
    "spec_sheets" => "fgss",
    "gizmo_returns" => "sales",
    "till_adjustments" => "bean counters",
    "worked_shifts" => "staff",
    "points_trades" => "hours",
    "volunteer_events" => "sked admin",
    "volunteer_default_events" => "sked admin",
    "default_assignments" => "sked admin",
    "volunteer_shifts" => "sked admin",
    "resources" => "sked admin",
    "skeds" => "sked admin",
    "rosters" => "sked admin",
    "volunteer_default_shifts" => "sked admin",
    "assignments" => "vol sked",
    }
  end

  def sidebar_stuff
    # base
    aliases = {:a => :action, :c => :controller}
    sidebar_hash = OH.n
    sidebar_hash.default_class = OH
    # hours
    sidebar_hash["hours"]["entry"] = {:c => "volunteer_tasks"}
    sidebar_hash["hours"]["points trade"] = {:c => 'points_trades'}
    # transactions
    for i in [:donation, :sale, :recycling, :disbursement, :gizmo_return] do
      pl = i.to_s.pluralize
      disp = pl.sub("gizmo_returns", "sales")
      prep = ([:sale, :gizmo_return].include?(i) ? pl.sub("gizmo_", "") + " " : "")
      sidebar_hash[disp][prep + "entry"] = {:c => pl}
      sidebar_hash[disp][prep + "search"] = {:c => pl, :a => 'search'}
    end
    sidebar_hash["sales"]["store credits"] = {:c => "store_credits", :a => 'index'}
    # reports
    ["income", "gizmos", "volunteering", "top_contributors"].each do |x|
      sidebar_hash["reports"][x.gsub(/_/, " ")] = {:c => "reports", :a => x.sub("ing", "s")}
    end
    sidebar_hash["reports"]["trends"] = {:c => 'graphic_reports'}
    # contacts
    sidebar_hash["contacts"]["contacts"] = {:c => "contacts"}
    sidebar_hash["contacts"]["dedup"] = {:c => 'contact_duplicates'}
    sidebar_hash["contacts"]["duplicates list"] = {:c => 'contact_duplicates', :a => "list_dups"}
    sidebar_hash["contacts"]["email list"] = {:c => 'contacts', :a => "email_list"}
    # bean counters
    sidebar_hash["bean counters"]["till adjustments"] = {:c => "till_adjustments"}
    # skedjuler
    sidebar_hash["sked admin"]["regular sked"] = {:c => "volunteer_default_shifts"}
    sidebar_hash["sked admin"]["real sked"] = {:c => "volunteer_shifts"}
    sidebar_hash["sked admin"]["default assign"] = {:c => "default_assignments"}
    sidebar_hash["vol sked"]["schedule"] = {:c => "assignments"}
    sidebar_hash["vol sked"]["search"] = {:c => "assignments", :a => "search"}
    # staffsched
    sidebar_hash["staff"]["schedule"] = {:c => "work_shifts", :a => "staffsched"} if should_show_schedule
    sidebar_hash["staff"]["holidays"] = {:c => "holidays", :a => "display"}
    sidebar_hash["staff"]["edit schedule"] = {:c => "work_shifts"} if should_show_edit_schedule
    sidebar_hash["staff"]["staff hours"] = {:c => "worked_shifts"}
    sidebar_hash["staff"]["individual report"] = {:c => "worked_shifts", :a => "individual"}
    sidebar_hash["staff"]["jobs report"] = {:c => "reports", :a => "staff_hours"}
    sidebar_hash["staff"]["types report"] = {:c => "worked_shifts", :a => "type_totals"}
    sidebar_hash["staff"]["payroll report"] = {:c => "worked_shifts", :a => "payroll"}
    sidebar_hash["staff"]["weekly report"] = {:c => "worked_shifts", :a => "weekly_workers"}
    # library
#    requires_librarian = ['overdue', 'labels', 'cataloging', 'borrowers', 'inventory']
#    for i in ['lookup', 'overdue', 'inventory', 'cataloging', 'search', 'labels', 'borrowers'] do
#      if !requires_librarian.include?(i) or has_privileges("LIBRARIAN")
#        sidebar_hash["library"][i] = {:c => "library", :a => i}
#      end
#    end
    # fgss
    sidebar_hash["fgss"]["printme"] = {:c => 'spec_sheets'}
    sidebar_hash["fgss"]["fix contract"] = {:c => 'spec_sheets', :a => "fix_contract"} if contract_enabled
    # done
    return aliases, sidebar_hash
  end
end
