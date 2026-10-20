class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :status, null: false
      t.string :note
      t.string :source, default: "email", null: false
      t.datetime :responded_at
      t.timestamps
    end
    add_index :rsvps, %i[meeting_id member_id], unique: true
  end
end
