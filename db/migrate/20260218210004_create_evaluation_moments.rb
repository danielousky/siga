class CreateEvaluationMoments < ActiveRecord::Migration[7.0]
  def change
    create_table :evaluation_moments do |t|
      t.string :name, null: false
      t.decimal :weight, precision: 5, scale: 2, null: false

      t.timestamps
    end
  end
end
