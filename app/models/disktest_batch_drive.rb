class DisktestBatchDrive < ActiveRecord::Base
  belongs_to :disktest_run
  belongs_to :disktest_batch
  belongs_to :user_destroyed_by, :class_name => "User"

  validates_presence_of :serial_number
  validates_presence_of :disktest_batch_id
  validates_existence_of :disktest_batch

  def disktest_run
    DisktestRun.find_by_id(self.disktest_run_id) || _find_run
  end

  def _find_run
    DisktestRun.find_all_by_serial_number(self.serial_number).select{|x| x.created_at >= self.date}.sort_by(&:created_at).last
  end

  def finalize_run
    run = _find_run
    self.disktest_run_id = run ? run.id : nil
  end
end
