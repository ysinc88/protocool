class CreateTaskAssignments < ActiveRecord::Migration[8.1]
  def up
    create_table :task_assignments do |t|
      t.references :task, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.datetime :emailed_at
      t.timestamps
    end
    add_index :task_assignments, %i[task_id member_id], unique: true

    execute <<~SQL
      INSERT INTO task_assignments (task_id, member_id, emailed_at, created_at, updated_at)
      SELECT id, member_id, emailed_at, created_at, updated_at FROM tasks WHERE member_id IS NOT NULL
    SQL
    remove_reference :tasks, :member, index: true
  end

  def down
    add_reference :tasks, :member, index: true
    execute <<~SQL
      UPDATE tasks SET member_id = (SELECT MIN(member_id) FROM task_assignments WHERE task_id = tasks.id)
    SQL
    drop_table :task_assignments
  end
end
