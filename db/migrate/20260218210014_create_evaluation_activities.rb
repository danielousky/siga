class CreateEvaluationActivities < ActiveRecord::Migration[7.0]
  def change
    create_table :evaluation_activities do |t|
      t.references :subject, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.references :evaluation_moment, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :weight_percentage, precision: 5, scale: 2, null: false
      t.date :date_scheduled, null: false

      t.timestamps
    end
  end
end
