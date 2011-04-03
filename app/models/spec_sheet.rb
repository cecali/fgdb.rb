class SpecSheet < ActiveRecord::Base
  include SystemHelper

  validates_presence_of :contact_id
  validates_presence_of :action_id
  validates_presence_of :type_id

  belongs_to :builder_task, :dependent => :destroy
  belongs_to :system
  belongs_to :type
  has_one :contract, :through => :system
  validates_associated :builder_task

  after_save :save_bt

  def save_bt
    self.builder_task.save!
  end

  validates_existence_of :type

  named_scope :good, :conditions => ["cleaned_valid = ? AND original_valid = ?", true, true]
  named_scope :bad, :conditions => ["cleaned_valid = ? AND original_valid = ?", false, false]
  named_scope :originally_bad, :conditions => ["cleaned_valid = ? AND original_valid = ?", true, false]
  named_scope :clean_broke_it, :conditions => ["cleaned_valid = ? AND original_valid = ?", false, true]

  before_save :set_contract_id_and_covered
  before_save :builder_task

  def contact
    self.builder_task.contact
  end

  def action
    self.builder_task.action
  end

  def contract_id
    @contract_id ||= (system ? system.contract_id : nil)
  end

  def contact_id
    contact ? contact.id : nil
  end

  def builder_task_with_magic
    builder_task_without_magic || self.builder_task=(BuilderTask.new)
  end
  alias_method_chain :builder_task, :magic

  def contact_id=(val)
    self.builder_task.contact_id = val
  end

  def action_id
    action ? action.id : nil
  end

  def action_id=(val)
    self.builder_task.action_id = val
  end

  def after_initialize
    builder_task
  end

  def signed_off_by
    self.builder_task.signed_off_by
  end

  def signed_off_by=(val)
    self.builder_task.signed_off_by = val
  end

  def notes
    self.builder_task.notes
  end

  def notes=(val)
    self.builder_task.notes = val
  end

  def contract_id=(val)
    @contract_id = val
  end

  def covered
    @covered ||= (system ? system.covered : nil)
  end

  def covered=(val)
    @covered = val
  end

  def bug_correction
    self.system.bug_correction
  end

  def bug_correction=(val)
    self.system.bug_correction=(val)
  end

  def set_contract_id_and_covered
    if system
      if !(@contract_id.nil? || !(c = Contract.find(@contract_id)))
        system.contract = c
        system.save!
      end
      if !(@covered.nil?)
        system.covered = @covered
        system.save!
      end
    end
  end

  def lshw_output=(val)
    # if this record has already been saved, then don't let it change.
    if id.nil?
      self._lshw_output=(val)
    end
  end

  def _lshw_output=(val)
#    write_attribute(:original_output, val)
    file = Tempfile.new("fgss-xml")
    file.write(original_output)
    file.flush
    write_attribute(:original_valid, Kernel.system("xmlstarlet val #{file.path} >/dev/null 2>/dev/null"))
    write_attribute(:cleaned_output, val.gsub(/[^[:print:]\n\t]/, ''))
    file = Tempfile.new("fgss-xml")
    file.write(cleaned_output)
    file.flush
    write_attribute(:cleaned_valid, Kernel.system("xmlstarlet val #{file.path} >/dev/null 2>/dev/null"))
  end

  def lshw_output
    if cleaned_valid
      return cleaned_output
    elsif original_valid
      return original_output
    else
      return ""
    end
  end

  def xml_is_good
    cleaned_valid || original_valid
  end

  def initialize(*args)
    super(*args)

    if !xml_is_good
      self.system_id = nil
      return
    end

    sp = SystemParser.parse(lshw_output)

    found_system = System.find_by_id(sp.find_system_id)
    if found_system and !found_system.gone?
      self.system = found_system
    else
      self.system = System.new
      system.previous_id = found_system.id if found_system
      system.system_model  = sp.system_model
      system.system_serial_number  = sp.system_serial_number
      system.system_vendor  = sp.system_vendor
      system.mobo_model  = sp.mobo_model
      system.mobo_serial_number  = sp.mobo_serial_number
      system.mobo_vendor  = sp.mobo_vendor
      system.model  = sp.model
      system.serial_number  = sp.serial_number
      system.vendor  = sp.vendor
    end
  end
end
