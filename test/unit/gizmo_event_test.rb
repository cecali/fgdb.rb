require File.dirname(__FILE__) + '/../test_helper'

class GizmoEventTest < Test::Unit::TestCase
  fixtures :gizmo_types

  def setup
    # Retrieve fixtures via their name
    # @first = gizmo_events(:first)
  end

  def test_that_empty_events_are_mostly_empty
    ev = GizmoEvent.new
    assert ev.mostly_empty?
    ev.gizmo_count = 2
    assert ev.mostly_empty?
    ev.gizmo_type = GizmoType.find(1)
    assert ! ev.mostly_empty?
  end

  def test_required_fee
    ge = GizmoEvent.new(crt_event)
    assert ge.valid?
    assert_kind_of GizmoType, ge.gizmo_type
    assert ge.gizmo_type.required_fee
    assert ge.gizmo_type.required_fee > 0
    assert ge.required_fee > 0
  end

end

