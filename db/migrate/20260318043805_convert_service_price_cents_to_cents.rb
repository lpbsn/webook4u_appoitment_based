class ConvertServicePriceCentsToCents < ActiveRecord::Migration[8.1]
  # Converts existing price_cents from euros (30, 60, 100) to cents (3000, 6000, 10000).
  # Run once after deploying; rollback divides by 100 (only safe for integer euro values).
  def up
    execute <<-SQL.squish
      UPDATE services SET price_cents = price_cents * 100
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE services SET price_cents = price_cents / 100
    SQL
  end
end
