class CreatePrinters < ActiveRecord::Migration
  def self.up
    create_table :printers do |t|
      # t.column :name, :string
    end
  end

  def self.down
    drop_table :printers
  end
end
