module DonationsHelper
  include TransactionHelper

  def base_controller
    return '/donations'
  end

  def columns
    [
     Column.new(Donation, :name => 'id'),
     Column.new(Donation, :name => 'payment',
                :eval  => 'donation.payment', :sortable => false),
     Column.new(Donation, :name => 'donor', :sortable => false,
                :eval => 'donation.donor'),
     Column.new(Donation, :name => 'gizmos', :sortable => false),
     Column.new(Donation, :name => 'reported_required_fee', :label => 'Required Fee'),
     Column.new(Donation, :name => 'reported_suggested_fee', :label => 'Suggested Fee'),
     Column.new(Donation, :name => 'occurred_at'),
    ]
  end
end
