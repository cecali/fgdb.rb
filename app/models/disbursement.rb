class Disbursement < ActiveRecord::Base
  include GizmoTransaction
  belongs_to :contact, :order => "surname, first_name"
  belongs_to :disbursement_type
  has_many :gizmo_events, :dependent => :destroy

  def validate
    errors.add_on_empty("contact_id")
    errors.add_on_empty("disbursed_at", "when?")
    errors.add_on_empty("disbursement_type_id")
    errors.add_on_empty("gizmo_events")
  end

  before_save :set_occurred_at_on_gizmo_events

  class << self
    def default_sort_sql
      "disbursements.disbursed_at DESC"
    end
  end

  def occurred_at
    disbursed_at
  end

  def recipient
    contact
  end

  #######
  private
  #######

  def set_occurred_at_on_gizmo_events
    self.gizmo_events.each {|event| event.occurred_at = self.disbursed_at}
  end
end
