class GizmoEvent < ActiveRecord::Base
  named_scope :not_discount, :conditions => ["gizmo_type_id != ?", GizmoType.find_by_name("fee_discount").id]

  belongs_to :donation
  belongs_to :sale
  belongs_to :gizmo_return
  belongs_to :disbursement
  belongs_to :recycling
  belongs_to :gizmo_type
  belongs_to :gizmo_category
  belongs_to :gizmo_context
  belongs_to :system
  has_many :store_credits

  validates_presence_of :gizmo_count
  validates_presence_of :gizmo_type_id
  validates_presence_of :gizmo_context_id

  before_save :set_storecredit_difference_cents, :if => :is_store_credit

  define_amount_methods_on("unit_price")

  def is_store_credit
    self.gizmo_type.id == GizmoType.find_by_name("store_credit").id
  end

  before_save :set_storecredit_on_return

  def set_storecredit_on_return
    if(@sc_id_set and @sc_id != self.return_store_credit_id)
      raise unless self.gizmo_context == GizmoContext.gizmo_return
      self.return_store_credit_id = @sc_id
    end
  end

  def store_credit_hash=(hash)
    return unless hash and hash.length > 0
    @sc_id_set = true
    begin
      @sc_id = StoreChecksum.new_from_checksum(hash).result
    rescue StoreChecksumException
      @sc_id = nil
    end
  end

  def store_credit_hash_id
    if ! @sc_id_set
      @sc_id_set = true
      @sc_id = self.return_store_credit_id
    end
    @sc_id
  end

  def store_credit_hash
    StoreChecksum.new_from_result(store_credit_hash_id).checksum if store_credit_hash_id
  end

  def my_sc_h
    StoreCredit.find_by_id(store_credit_hash_id)
  end

  validate :sc_h_ok

  def sc_h_ok
    return if !(is_store_credit && self.gizmo_context == GizmoContext.gizmo_return)
    errors.add("gizmo_event", "store credit was already spent") if self.my_sc_h.spent? && (self.gizmo_return.id.nil? || self.my_sc_h.payment_id || ((self.my_sc_h.my_return.gizmo_return.id) != self.gizmo_return.id))
  end

  attr_accessor :expire_date

  def set_storecredit_difference_cents
    return unless self.gizmo_context == GizmoContext.sale
    my_expire_date = self.store_credits.map{|x| x.expire_date}.uniq.select{|x| !x.nil?}.sort.last
    my_expire_date ||= @expire_date
    my_expire_date ||= (Date.today + StoreCredit.expire_after_value)
    while self.store_credits.length < self.gizmo_count
      self.store_credits << StoreCredit.new
    end
    while self.store_credits.length > self.gizmo_count
      raise if store_credits.last.spent?
      self.store_credits.pop
    end
    self.store_credits.each{|x|
      raise if x.spent? and x.amount_cents != self.unit_price_cents
      x.amount_cents = self.unit_price_cents
      x.expire_date = my_expire_date
    }
  end

  def editable
    self.gizmo_type.name != "store_credit" || !self.spent?
  end

  def spent?
    for i in self.store_credits
      return true if i.spent?
    end
    return false
  end

  def my_transaction
    return sale || donation || gizmo_return || disbursement || recycling
  end

  def validate
    if gizmo_type && gizmo_type.gizmo_category && gizmo_type.gizmo_category.name == "system" && !system_id.nil? && gizmo_count != 1
      errors.add("gizmo_count", "should be 1 if you enter a system id")
    end
    if (!gizmo_type || !gizmo_type.gizmo_category || gizmo_type.gizmo_category.name != "system") && !system_id.nil?
      errors.add("system_id", "should only be set if the type is a system")
    end
    if !system_id.nil? && self.system.nil?
      errors.add("system_id", "does not refer to a valid system")
    end
  end

  class << self
    def totals(conditions)
      connection.execute(
                         "SELECT gizmo_types.gizmo_category_id,
                gizmo_events.gizmo_type_id,
                gizmo_events.gizmo_context_id,
                d.disbursement_type_id,
                sum(gizmo_events.gizmo_count) AS count
         FROM gizmo_events
              LEFT OUTER JOIN disbursements AS d ON d.id = gizmo_events.disbursement_id
              LEFT JOIN gizmo_types ON gizmo_types.id=gizmo_events.gizmo_type_id
LEFT JOIN donations ON gizmo_events.donation_id = donations.id LEFT JOIN systems ON system_id = systems.id
         WHERE #{sanitize_sql_for_conditions(conditions)}
         GROUP BY 3,2,4,1"
                         )
    end
  end

  def display_name
    "%i %s%s" % [gizmo_count, gizmo_type.description, gizmo_count > 1 ? 's' : '']
  end

  def valid_gizmo_count?
    gizmo_count.is_a?(Fixnum) and gizmo_count > 0
  end

  def store_credit_ids
    self.store_credits.map{|x| "#" + x.id.to_s}.to_sentence
  end

  def store_credit_hashes
    self.store_credits.map{|x| "#" + x.store_credit_hash}.to_sentence
  end

  def original_sale_id
    return_sale_id
  end

  def attry_description(options = {})
    junk = [:as_is, :size, :system_id, :original_sale_id].map{|x| x.to_s} - (options[:ignore] || [])

    junk.reject!{|x| z = eval("self.#{x}"); z.nil? || z.to_s.empty?}

    g_desc = gizmo_type.description
    m_desc = self.description
    desc = g_desc
    desc += " -- " + m_desc if !(m_desc.nil? || m_desc.empty?)

    if junk.empty?
      return desc
    else
      return desc + "(" + junk.map{|x| x.to_s.classify.gsub(/(.)([A-Z])/, "\\1 \\2") + ": " + eval("self.#{x}").to_s}.join(", ") + ")"
    end
  end

  def percent_discount(schedule)
    return 0 unless schedule && gizmo_type
    ( ( 1.0 - gizmo_type.multiplier_to_apply(schedule, self.my_transaction.occurred_at) ) * 100 ).ceil
  end

  def total_price_cents
    return 0 unless unit_price_cents and gizmo_count
    unit_price_cents * gizmo_count
  end

  def discounted_price(schedule)
    return total_price_cents unless schedule && gizmo_type
    (total_price_cents * (gizmo_type.multiplier_to_apply(schedule, self.my_transaction.occurred_at) * 100).to_i)/100
  end

  def mostly_empty?
    ((! gizmo_type_id) or (! gizmo_count))
  end

  def fee_cents
    unit_price_cents
  end

  def required_fee_cents
    if !covered && gizmo_type.required_fee_cents != 0 || gizmo_type.name == "fee_discount"
      gizmo_count.to_i * (unit_price_cents || gizmo_type.required_fee_cents)
    else
      0
    end
  end

  def suggested_fee_cents
    if (covered && gizmo_type.required_fee_cents != 0) || gizmo_type.suggested_fee_cents != 0
      gizmo_count.to_i * (unit_price_cents || gizmo_type.suggested_fee_cents || gizmo_type.required_fee_cents)
    else
      0
    end
  end

  def to_s
    "id[#{id}]; type[#{gizmo_type_id}]; context[#{gizmo_context_id}]; count[#{gizmo_count}]"
  end
end
