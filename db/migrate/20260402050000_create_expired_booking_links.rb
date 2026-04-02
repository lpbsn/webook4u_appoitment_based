class CreateExpiredBookingLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :expired_booking_links do |t|
      t.references :client, null: false, foreign_key: true
      t.string :pending_access_token, null: false
      t.bigint :enseigne_id
      t.bigint :service_id
      t.date :booking_date, null: false
      t.datetime :expired_at, null: false

      t.timestamps
    end

    add_index :expired_booking_links,
              [ :client_id, :pending_access_token ],
              unique: true,
              name: "index_expired_booking_links_on_client_and_token"
    add_index :expired_booking_links, :expired_at
  end
end
