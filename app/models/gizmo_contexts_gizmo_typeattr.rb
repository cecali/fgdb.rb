require 'ajax_scaffold'

class GizmoContextsGizmoTypeattr < ActiveRecord::Base
  belongs_to  :gizmo_context
  belongs_to  :gizmo_typeattr

  def to_s
    "context[#{gizmo_context}]; typeattr[#{gizmo_typeattr}]"
  end

end
