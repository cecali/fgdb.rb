require 'ajax_scaffold'

class GizmoEventsGizmoTypeattr < ActiveRecord::Base
  belongs_to  :gizmo_typeattr
  belongs_to  :gizmo_event

#  def to_s
#    relevant_vals = %W[text boolean integer monetary].each do |tag|
#      colname = "attr_val_" + tag
#      self.send(colname)
#    end
#    relevant_vals.compact!
#    "typeattr[#{gizmo_typeattr_id}]; event[#{gizmo_event_id}]; value[#{relevant_vals.join(', ')}]"
#  end

end
