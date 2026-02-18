class CreateStudents < ActiveRecord::Migration[7.0]
  def change
    create_table :students, id: false do |t|
      t.bigint :user_id, null: false, primary_key: true
      t.string :school_card, null: false
      t.references :school, null: false, foreign_key: true

      t.timestamps
    end

    add_foreign_key :students, :users, column: :user_id
    add_index :students, :school_card, unique: true
  end
end
