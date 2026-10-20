# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_000002) do
  create_table "meetings", force: :cascade do |t|
    t.datetime "scheduled_at", null: false
    t.string "location"
    t.text "agenda"
    t.datetime "reminder_sent_at"
    t.text "protocol_text"
    t.string "protocol_source"
    t.text "summary"
    t.text "decisions"
    t.text "community_letter"
    t.string "processing_status"
    t.text "processing_error"
    t.datetime "processed_at"
    t.datetime "tasks_sent_at"
    t.datetime "letter_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_at"], name: "index_meetings_on_scheduled_at"
  end

  create_table "members", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "role"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_members_on_email", unique: true
  end

  create_table "processed_messages", force: :cascade do |t|
    t.string "message_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_processed_messages_on_message_id", unique: true
  end

  create_table "recordings", force: :cascade do |t|
    t.integer "meeting_id", null: false
    t.string "status", default: "recording", null: false
    t.string "mime_type"
    t.integer "bytes", default: 0, null: false
    t.float "duration_seconds"
    t.integer "num_speakers"
    t.json "segments"
    t.json "speaker_names"
    t.text "error"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stage"
    t.integer "progress"
    t.index ["meeting_id"], name: "index_recordings_on_meeting_id"
  end

  create_table "rsvps", force: :cascade do |t|
    t.integer "meeting_id", null: false
    t.integer "member_id", null: false
    t.string "status", null: false
    t.string "note"
    t.string "source", default: "email", null: false
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "member_id"], name: "index_rsvps_on_meeting_id_and_member_id", unique: true
    t.index ["meeting_id"], name: "index_rsvps_on_meeting_id"
    t.index ["member_id"], name: "index_rsvps_on_member_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "committee_name", default: "ועדת חינוך"
    t.string "settlement_name"
    t.string "chair_name"
    t.string "gmail_address"
    t.text "gmail_app_password"
    t.string "community_email"
    t.integer "reminder_days_before", default: 2, null: false
    t.integer "reminder_hour", default: 9, null: false
    t.string "default_location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "task_assignments", force: :cascade do |t|
    t.integer "task_id", null: false
    t.integer "member_id", null: false
    t.datetime "emailed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["member_id"], name: "index_task_assignments_on_member_id"
    t.index ["task_id", "member_id"], name: "index_task_assignments_on_task_id_and_member_id", unique: true
    t.index ["task_id"], name: "index_task_assignments_on_task_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "meeting_id", null: false
    t.string "assignee_name"
    t.text "description", null: false
    t.date "due_on"
    t.boolean "done", default: false, null: false
    t.datetime "emailed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_tasks_on_meeting_id"
  end

  create_table "topic_suggestions", force: :cascade do |t|
    t.integer "meeting_id", null: false
    t.integer "member_id"
    t.string "from_email"
    t.text "body", null: false
    t.string "message_id"
    t.boolean "accepted", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_topic_suggestions_on_meeting_id"
    t.index ["member_id"], name: "index_topic_suggestions_on_member_id"
    t.index ["message_id"], name: "index_topic_suggestions_on_message_id"
  end

  add_foreign_key "recordings", "meetings"
  add_foreign_key "rsvps", "meetings"
  add_foreign_key "rsvps", "members"
  add_foreign_key "task_assignments", "members"
  add_foreign_key "task_assignments", "tasks"
  add_foreign_key "tasks", "meetings"
  add_foreign_key "topic_suggestions", "meetings"
  add_foreign_key "topic_suggestions", "members"
end
