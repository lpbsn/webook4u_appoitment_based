class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :client, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.string :customer_name
      t.string :customer_email
      t.datetime :start_time
      t.datetime :end_time
      t.string :status
      t.datetime :expires_at
      t.string :stripe_session_id
      t.string :stripe_payment_intent

      t.timestamps
    end
  end
end
