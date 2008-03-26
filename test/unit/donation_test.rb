require File.dirname(__FILE__) + '/../test_helper'

class DonationTest < Test::Unit::TestCase

#   fixtures :contact_types, :contact_method_types, :contacts, :payment_methods, :gizmo_contexts,
#     :gizmo_attrs, :gizmo_types, :gizmo_typeattrs,
#     :gizmo_contexts_gizmo_typeattrs, :gizmo_contexts_gizmo_types, :donations
  load_all_fixtures

  NO_INFO = {:created_by => 1}
  WITH_CONTACT_INFO = NO_INFO.merge({:postal_code => '54321', :contact_type => 'anonymous'})

  def with_gizmo
    NO_INFO.merge({:gizmo_events => [GizmoEvent.new(system_event)]})
  end

  def with_both
    with_gizmo().merge( WITH_CONTACT_INFO )
  end

  def with_too_much_contact_info
    with_both().merge({:contact_id => 1})
  end

  def setup
    # Retrieve fixtures via their name
    # @first = donations(:first)
  end

  def test_that_should_not_be_valid_without_contact_info
    donation = Donation.new(NO_INFO)
    assert ! donation.valid?
    #assert donation.errors.invalid?(:contact_id), "Should require contact for initialization"
  end

  def test_that_should_be_valid_with_contact_info
    donation = Donation.new(with_gizmo.merge(:postal_code => '12345'))
    assert donation.valid?
    donation = Donation.new(with_gizmo.merge(:contact_id => '1'))
    #assert donation.valid?
  end

  def test_that_should_be_valid_when_dumped
    donation = Donation.new(NO_INFO.merge({:gizmo_events => [GizmoEvent.new(crt_event)], :contact_type => 'dumped'}))
    assert donation.valid?
  end

  def test_that_should_dumped_contact_type_should_be_remembered
    donation = Donation.new(NO_INFO.merge({:gizmo_events => [GizmoEvent.new(crt_event)],
                                           :contact_type => 'dumped'}))
    assert donation.save
    donation = Donation.find(donation.id)
    assert_equal 'dumped', donation.donor
    assert_equal 'dumped', donation.contact_type
  end

  def test_that_anonymous_contact_without_postal_code_should_be_invalid
    donation = Donation.new(NO_INFO.merge({:gizmo_events => [GizmoEvent.new(crt_event)], :contact_type => 'anonymous'}))
    assert !donation.valid?
  end

  def test_that_should_be_able_to_get_contact_information_for_anonymous
    donation = Donation.new(with_gizmo.merge(:postal_code => '12345'))
    info = nil
    assert_nothing_raised       {info = donation.contact_information}
    assert                      info
    assert_kind_of              Array, info
    assert                      ! info.empty?
    assert_kind_of              String, info[0]
    assert_match                /12345/, info[0]
  end

  def test_that_should_sum_amounts_from_payments
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    donation.payments << Payment.new({ :amount => 2, :payment_method_id => 3 })
    donation.payments << Payment.new({ :amount => 3.5, :payment_method_id => 2 })
    donation.payments << Payment.new({ :amount => 1, :payment_method_id => 1 })
    donation.payments << Payment.new({ :amount => 0, :payment_method_id => 1 })
    assert_equal 6.5, donation.money_tendered
  end

  def test_that_real_payments_excludes_invoices
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    donation.payments << Payment.new({ :amount => 2, :payment_method_id => 3 })
    invoice = Payment.new({ :amount => 3.5 })
    invoice.payment_method = PaymentMethod.invoice
    donation.payments << invoice
    assert ! donation.real_payments.include?( invoice )
  end

  def test_that_should_not_include_invoices_in_payment_amount
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    donation.payments << Payment.new({ :amount => 2, :payment_method_id => 3 })
    invoice = Payment.new({ :amount => 3.5 })
    invoice.payment_method = PaymentMethod.invoice
    donation.payments << invoice
    assert_equal 2, donation.money_tendered
  end

  def test_that_should_total_invoiced_amount
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    donation.payments << Payment.new({ :amount => 2, :payment_method_id => 3 })
    invoice = Payment.new({ :amount => 3.5 })
    invoice.payment_method = PaymentMethod.invoice
    donation.payments << invoice
    assert (3.5 - donation.amount_invoiced).abs() < 0.001
  end

  def test_that_should_be_able_to_tell_when_to_invoice
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    assert ! donation.invoiced?
    donation.payments << Payment.new({ :amount => 2, :payment_method_id => 3 })
    assert ! donation.invoiced?
    invoice = Payment.new({ :amount => 3.5 })
    invoice.payment_method = PaymentMethod.invoice
    donation.payments << invoice
    assert donation.invoiced?
  end

  def test_that_required_fees_should_not_be_valid_unpaid
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.payments = []
    donation.gizmo_events = [GizmoEvent.new(crt_event)]
    assert( donation.calculated_required_fee > 0, "a crt should have a required fee" )
    assert( ! donation.valid? )
  end

  def test_that_required_fees_should_be_valid_paid
    donation = Donation.new(WITH_CONTACT_INFO)
    donation.gizmo_events = [GizmoEvent.new(crt_event)]
    assert ! donation.gizmo_events.empty?
    assert donation.gizmo_events[0].gizmo_type.required_fee > 0
    assert( donation.calculated_required_fee > 0, "a crt should have a required fee" )
    assert( ! donation.valid? )
    donation.payments = [Payment.new({ :amount => 10, :payment_method_id => 3 })]
    assert( donation.valid? )
  end

  def test_that_payments_or_gizmos_are_required
    donation = Donation.new(WITH_CONTACT_INFO)
    assert ! donation.valid?
    donation.payments << Payment.new({ :amount => 10, :payment_method_id => 3 })
    assert donation.valid?
    donation.payments = []
    assert ! donation.valid?
  end

    Test::Unit::TestCase.integer_math_test(self, "Donation", "reported_suggested_fee")
    Test::Unit::TestCase.integer_math_test(self, "Donation", "reported_required_fee")

  def test_that_donations_use_contact_type_first
    donation = Donation.new(with_too_much_contact_info)
    assert_equal with_too_much_contact_info[:contact_type], donation.contact_type
    assert donation.save
    assert_equal with_too_much_contact_info[:contact_type], Donation.find(donation.id).contact_type
  end

  def test_that_gizmo_events_occurred_when_donated
    donation = Donation.new(WITH_CONTACT_INFO)
    yesterday = Date.today - 1
    donation.created_at = yesterday
    donation.gizmo_events = [GizmoEvent.new(recycled_system_event)]
    assert donation.save
    donation = Donation.find(donation.id)
    event = donation.gizmo_events[0]
    assert_equal donation.created_at, event.occurred_at
    assert_not_equal event.created_at, event.occurred_at
  end

end
