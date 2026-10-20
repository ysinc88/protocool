class CreateCore < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :committee_name, default: "ועדת חינוך"
      t.string :settlement_name
      t.string :chair_name
      t.string :gmail_address
      t.text :gmail_app_password
      t.string :community_email
      t.integer :reminder_days_before, default: 2, null: false
      t.integer :reminder_hour, default: 9, null: false
      t.string :default_location
      t.timestamps
    end

    create_table :members do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :role
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :members, :email, unique: true

    create_table :meetings do |t|
      t.datetime :scheduled_at, null: false
      t.string :location
      t.text :agenda
      t.datetime :reminder_sent_at
      t.text :protocol_text
      t.string :protocol_source
      t.text :summary
      t.text :decisions
      t.text :community_letter
      t.string :processing_status
      t.text :processing_error
      t.datetime :processed_at
      t.datetime :tasks_sent_at
      t.datetime :letter_sent_at
      t.timestamps
    end
    add_index :meetings, :scheduled_at

    create_table :topic_suggestions do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :member, foreign_key: true
      t.string :from_email
      t.text :body, null: false
      t.string :message_id
      t.boolean :accepted, default: true, null: false
      t.timestamps
    end
    add_index :topic_suggestions, :message_id

    create_table :tasks do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :member, foreign_key: true
      t.string :assignee_name
      t.text :description, null: false
      t.date :due_on
      t.boolean :done, default: false, null: false
      t.datetime :emailed_at
      t.timestamps
    end

    create_table :recordings do |t|
      t.references :meeting, null: false, foreign_key: true
      t.string :status, null: false, default: "recording"
      t.string :mime_type
      t.integer :bytes, default: 0, null: false
      t.float :duration_seconds
      t.integer :num_speakers
      t.json :segments
      t.json :speaker_names
      t.text :error
      t.datetime :finished_at
      t.timestamps
    end

    create_table :processed_messages do |t|
      t.string :message_id, null: false
      t.timestamps
    end
    add_index :processed_messages, :message_id, unique: true
  end
end
