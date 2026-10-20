class AddProgressToRecordings < ActiveRecord::Migration[8.1]
  def change
    add_column :recordings, :stage, :string
    add_column :recordings, :progress, :integer
  end
end
