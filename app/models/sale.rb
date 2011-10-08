class Sale < ActiveRecord::Base
  acts_as_userstamp

  include GizmoTransaction
  belongs_to :contact
  has_many :payments, :dependent => :destroy
  belongs_to :discount_schedule
  has_many :gizmo_events, :dependent => :destroy
  has_many :gizmo_types, :through => :gizmo_events

  def gizmo_context
    GizmoContext.sale
  end

  before_save :add_contact_types
  before_save :unzero_contact_id
  before_save :compute_fee_totals
  before_save :add_change_line_item
  before_save :set_occurred_at_on_gizmo_events
  before_save :combine_cash_payments
  before_save :set_occurred_at_on_transaction
  before_save :strip_postal_code

  def initialize(*args)
    @contact_type = 'anonymous'
    super(*args)
  end

  # Quick Testing: ./script/runner 'class F; include RawReceiptHelper; def session; {}; end; end; puts F.new.generate_raw_receipt(Sale.last.text_receipt_lines)'
  def text_receipt_lines(fulllimit)
    store_credit_gizmo_events = self.gizmo_events.select{|x| x.gizmo_type.name == "store_credit"}
    other_gizmo_events = self.gizmo_events - store_credit_gizmo_events
    gizmo_lines =  []
    other_gizmo_events.each{|event|
      iszero = event.percent_discount(self.discount_schedule) == 0
      gizmo_lines << [ 'left', event.attry_description( :upcase => true, :ignore => ['unit_price'] ) ]
      gizmo_lines << ['right', event.gizmo_count.to_s + ' @', event.unit_price.to_s, iszero ? '' : event.total_price_cents.to_dollars.to_s, iszero ? '' : ('less ' + event.percent_discount(self.discount_schedule).to_s + "%"), event.discounted_price(self.discount_schedule).to_dollars.to_s]
    }
    store_credit_gizmo_events_total_cents = store_credit_gizmo_events.inject(0){|t,x| t+=x.total_price_cents} 
    gizmo_lines << []
    payment_lines = []
    unless self.calculated_discount_cents == 0
      payment_lines << ['right', "Subtotal:", "#{(self.calculated_subtotal_cents - store_credit_gizmo_events_total_cents).to_dollars}"]
      payment_lines << ['right', "Discounted:", "#{self.calculated_discount_cents.to_dollars}"]
    end
    payment_lines << ['right', "Total:", "#{(self.calculated_total_cents - store_credit_gizmo_events_total_cents).to_dollars}"]
    seen_sc = false
    cash_back = (defined?(@cash_back) and @cash_back > 0) ? @cash_back : 0
    self.payments.each{|payment|
      amount = payment.amount_cents
      if payment.payment_method.name == "store_credit" and !seen_sc
        amount -= store_credit_gizmo_events_total_cents
        seen_sc = true
      end
      payment_lines << ['right', payment.payment_method.description + ":", (amount + ((payment.payment_method.name == "cash") ? cash_back : 0)).to_dollars]
    }
    if cash_back > 0
      payment_lines << ['right', "change due:", "#{cash_back.to_dollars}"]
    end
    if store_credit_gizmo_events_total_cents > 0 and !seen_sc
      payment_lines << ['right', "store credit:", (-1 * store_credit_gizmo_events_total_cents).to_dollars]
    end
    if self.calculated_total_cents > self.money_tendered_cents && !self.invoice_resolved?
      payment_lines << ['right',     "Due by #{self.created_at.to_date + 30 }:", (self.calculated_total_cents - self.money_tendered_cents).to_dollars]
    end

    head_lines =   ["+---------------------------+",
    "| Free Geek Thrift Store    |",
  "| 1731 SE 10th Ave. PDX     |",
  "| 10-6 Tues. through Sat.   |",
  "| freegeek.org/thrift-store |",
   "+---------------------------+"].map{|x| ['center', x]}
    head_lines = head_lines + [[],
                               ['two', " #{self.occurred_at.strftime("%H:%M %p %m/%d/%y").downcase}", "sale: #{self.id}"],
                               ['two', " cashier: #{User.find_by_id(self.read_attribute(:cashier_created_by)).contact_id}", "cust: #{self.contact_id || "anonymous"}"]]
    if self.discount_schedule.name != 'no_discount'
      percent = (100 - (100 * self.discount_schedule.discount_schedules_gizmo_types.find_by_gizmo_type_id(GizmoType.find_by_name_and_ineffective_on('gizmo', nil).id).multiplier)) # FIXME: ineffective_on shouldn't be nil, it should find was effective during the self.created at of this
      head_lines << []
      head_lines << ['center', "### #{sprintf('%d', percent)}% #{self.discount_schedule.name.upcase} DISCOUNT APPLIED ###"]
    end
    head_lines << []
    footer_lines = [[]] + self.gizmo_events.map(&:gizmo_type).map{|x| x.my_return_policy_id}.select{|x| !x.nil?}.uniq.sort.map{|x| ReturnPolicy.find_by_id(x)}.map{|x| ['left', x.full_text]}
    thanks = []
    if fulllimit == 44
thanks = [
"      _                    _            ",
"     | |                  | |        |||",
" _|_ | |     __,   _  _   | |   ,    |||",
"  |  |/ \\   /  |  / |/ |  |/_) / \\_  |||",
"  |_/|   |_/\\_/|_/  |  |_/| \\_/ \\/   ooo"].map{|t| ['standard', t]}
    end
    final = head_lines + gizmo_lines + payment_lines + footer_lines + thanks
    final
  end

  attr_accessor :contact_type  #anonymous or named

  define_amount_methods_on("reported_discount_amount")
  define_amount_methods_on("reported_amount_due")

  def storecredits
    self.gizmo_events.map{|x| x.store_credits}.flatten
  end

  def validate
    unless is_adjustment?
    if contact_type == 'named'
      errors.add_on_empty("contact_id")
      if contact_id.to_i == 0 or !Contact.exists?(contact_id)
        errors.add("contact_id", "does not refer to any single, unique contact")
      end
    else
      errors.add_on_empty("postal_code")
    end
    end
    errors.add("payments", "are too little to cover the cost") unless invoiced? or total_paid?
    #errors.add("payments", "are too much") if overpaid?
    errors.add("payments", "may only have one invoice") if invoices.length > 1
    errors.add("gizmos", "should include something") if gizmo_events.empty?
    errors.add("payments", "use the same store credit multiple times") if storecredits_repeat

    payments.each{|x|
      x.errors.each{|y, z|
        errors.add("payments", z)
      }
    }
    gizmo_events.each{|x|
      x.errors.each{|y, z|
        errors.add("gizmos", z)
      }
    }

    storecred_received = self.storecredits.inject(0){|t,x| t += x.amount_cents}
    storecred_spent = amount_from_some_payments(store_credits_spent)
    oldstorecredit = 0
    if self.id
      oldstorecredit = self.class.find_by_id(self.id).storecredits.inject(0){|t,x| t += x.amount_cents}
    end
    storecredit_priv_check if storecred_received > storecred_spent and storecred_received > oldstorecredit
  end

  def storecredits_repeat
    sc = self.payments.select{|x| x.payment_method == PaymentMethod.store_credit}.map{|x| x.store_credit_id}
    sc.length != sc.uniq.length
  end

  class << self
    def default_sort_sql
      "sales.occurred_at DESC"
    end

    def totals(conditions)
      connection.execute(
                         "SELECT payments.payment_method_id,
                sum(payments.amount_cents) as amount,
                count(*),
                min(sales.id),
                max(sales.id)
         FROM sales
         JOIN payments ON payments.sale_id = sales.id
         WHERE #{sanitize_sql_for_conditions(conditions)}
         GROUP BY payments.payment_method_id"
                         )
    end
  end

  def buyer
    contact ?
    contact.display_name :
      "anonymous(#{postal_code})"
  end

  def contact_type
    @contact_type ||= contact ? 'named' : 'anonymous'
  end

  def required_contact_type
    ContactType.find_by_name('buyer')
  end

  def calculated_total_cents
    if discount_schedule
      gizmo_events.inject(0) {|tot,gizmo|
        gizmo.sale = self
        tot + gizmo.discounted_price(discount_schedule)
      }
    else
      calculated_subtotal_cents
    end
  end

  def calculated_discount_cents
    calculated_subtotal_cents - calculated_total_cents
  end

  def store_credits_spent
    payments.select{|x| x.is_storecredit?}
  end

  def other_spent # not store credit
    payments.select{|x| !x.is_storecredit?}
  end

  #########
  protected
  #########

  def compute_fee_totals
    self.reported_amount_due_cents = self.calculated_total_cents
    self.reported_discount_amount_cents = self.calculated_discount_cents
  end

  # WOAH! commented code.
  def _figure_it_all_out
    amount_i_owe = calculated_total_cents
    money_given = amount_from_some_payments(other_spent)
    storecredit_given = amount_from_some_payments(store_credits_spent)

    amount_i_owe -= storecredit_given
    if amount_i_owe < 0 # more store credit than the amount to be spent
      storecredit_to_give_back = -1 * amount_i_owe
      cash_to_give_back = money_given
      return [storecredit_to_give_back, cash_to_give_back]
    end

    # ok, either the store credit was just right, or we owe more money

    amount_i_owe -= money_given
    if amount_i_owe < 0 # more money was given than the amount to be spent
      storecredit_to_give_back = 0
      cash_to_give_back = -1 * amount_i_owe
      return [storecredit_to_give_back, cash_to_give_back]
    end

    if amount_i_owe == 0
      return [0, 0]
    end

    # amount_i_owe > 0 ... still need to pay more.
    return [0, 0]
  end

  def add_change_line_item()
    if self.payments.length == 1 and self.payments.first.payment_method.id == PaymentMethod.credit.id
      self.payments.first.amount_cents = self.calculated_total_cents
      self.payments.first.save
      return
    end
    storecredit_back, cash_back = _figure_it_all_out
    if storecredit_back > 0
      # wow, if only I had a working test suite...testing this through the UI is a PITA!!!!
      # mebbe we should fix that.
      gizmo_events << GizmoEvent.new({:unit_price_cents => storecredit_back,
                            :gizmo_count => 1,
                            :gizmo_type => GizmoType.find_by_name("store_credit"),
                                       :gizmo_context => self.gizmo_context})
# <Ryan52> so it should just recalculate the expire date always? <store> yeah, that's it
#                            :expire_date => store_credits_spent.map{|x| x.store_credit.expire_date}.uniq.select{|x| !x.nil?}.sort.last}) # WTF? something sets gizmo_context on *everything* else. why doesn't it set it on this one? hm...I can't find that code anyway.
    end
    if cash_back > 0
      payments << Payment.new({:amount_cents => -cash_back,
                                :payment_method => PaymentMethod.cash})
    end
    @cash_back = cash_back
  end
end
