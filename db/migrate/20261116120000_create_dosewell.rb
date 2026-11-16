class CreateDosewell < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :role, null: false
      t.string :timezone, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN ('doctor', 'patient', 'pharmacist')", name: "users_role_check"

    create_table :medications do |t|
      t.string :name, null: false
      t.string :generic_name, null: false
      t.string :ingredient, null: false
      t.string :strength, null: false
      t.string :form, null: false
      t.timestamps
    end
    add_index :medications, :ingredient
    add_index :medications, %i[name strength], unique: true

    create_table :allergies do |t|
      t.references :patient, null: false, foreign_key: { to_table: :users }
      t.string :ingredient, null: false
      t.timestamps
    end
    add_index :allergies, %i[patient_id ingredient], unique: true

    create_table :interactions do |t|
      t.references :medication_a, null: false, foreign_key: { to_table: :medications }
      t.references :medication_b, null: false, foreign_key: { to_table: :medications }
      t.string :severity, null: false
      t.string :description, null: false
      t.timestamps
    end
    add_index :interactions, %i[medication_a_id medication_b_id], unique: true, name: "index_interactions_on_pair"
    add_check_constraint :interactions, "severity IN ('major', 'moderate', 'minor')", name: "interactions_severity_check"
    add_check_constraint :interactions, "medication_a_id < medication_b_id", name: "interactions_ordered_pair_check"

    create_table :prescriptions do |t|
      t.references :patient, null: false, foreign_key: { to_table: :users }
      t.references :doctor, null: false, foreign_key: { to_table: :users }
      t.references :medication, null: false, foreign_key: true
      t.decimal :dose_quantity, precision: 8, scale: 2, null: false
      t.string :dose_unit, null: false
      t.string :frequency, null: false
      t.integer :interval_hours
      t.jsonb :times_of_day, null: false, default: []
      t.integer :duration_days, null: false
      t.date :start_date, null: false
      t.string :timezone, null: false
      t.string :status, null: false, default: "active"
      t.boolean :warning_acknowledged, null: false, default: false
      t.jsonb :warnings, null: false, default: []
      t.timestamps
    end
    add_index :prescriptions, %i[patient_id status]
    add_check_constraint :prescriptions,
      "frequency IN ('once_daily', 'twice_daily', 'three_times_daily', 'every_n_hours')",
      name: "prescriptions_frequency_check"
    add_check_constraint :prescriptions, "status IN ('active', 'cancelled')", name: "prescriptions_status_check"

    create_table :doses do |t|
      t.references :prescription, null: false, foreign_key: true
      t.references :patient, null: false, foreign_key: { to_table: :users }
      t.datetime :scheduled_at, null: false
      t.date :local_date, null: false
      t.string :local_time, null: false
      t.boolean :dst_adjusted, null: false, default: false
      t.string :status, null: false, default: "scheduled"
      t.datetime :recorded_at
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :doses, %i[patient_id scheduled_at]
    add_index :doses, %i[prescription_id scheduled_at], unique: true
    add_check_constraint :doses, "status IN ('scheduled', 'taken', 'missed')", name: "doses_status_check"

    create_table :audit_logs do |t|
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.string :summary, null: false
      t.jsonb :change_set, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :audit_logs, %i[auditable_type auditable_id]
    add_index :audit_logs, :created_at
  end
end
