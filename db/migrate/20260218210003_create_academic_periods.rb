class CreateAcademicPeriods < ActiveRecord::Migration[7.0]
  def change
    create_table :academic_periods do |t|
      t.references :school, null: false, foreign_key: true
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false

      t.timestamps
    end
  end
end
