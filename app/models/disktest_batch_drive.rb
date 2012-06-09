class DisktestBatchDrive < ActiveRecord::Base
  belongs_to :disktest_run
  belongs_to :disktest_batch
  belongs_to :user_destroyed_by, :class_name => "User"

  validates_presence_of :serial_number
#  validates_presence_of :disktest_batch_id
#  validates_existence_of :disktest_batch

  def disktest_run
    DisktestRun.find_by_id(self.disktest_run_id) || (self.disktest_batch.finalized? ? nil : _find_run)
  end

  def _find_run
    DisktestRun.find_all_by_serial_number(self.serial_number).select{|x| x.created_at >= self.disktest_batch.date and x.result != 'UNTESTED'}.sort_by(&:created_at).last
  end

  def wiped?
    (!self.destroyed_at) and self.disktest_run.result == "PASSED"
  end

  def destroyed?
    !! self.destroyed_at
  end

  def untested?
    not (wiped? or destroyed?)
  end

  def status
    self.destroyed_at.nil? ? (self.disktest_run ? self.disktest_run.status.sub(/PASSED/, "Wiped") : "Not yet tested.") : "Destroyed at #{self.destroyed_at}"
  end

  def mark_destroyed
    self.user_destroyed_by = Thread.current['cashier']
    self.destroyed_at = Time.now
  end

  def status=(foo)
    nil # noop
  end

  def finalize_run
    run = _find_run
    self.disktest_run_id = run ? run.id : nil
  end
end
