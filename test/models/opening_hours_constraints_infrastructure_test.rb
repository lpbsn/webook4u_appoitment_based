require "test_helper"

class OpeningHoursConstraintsInfrastructureTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Client opening hours infra", slug: "client-opening-hours-infra")
    @other_client = Client.create!(name: "Client opening hours infra 2", slug: "client-opening-hours-infra-2")
    @enseigne = @client.enseignes.create!(name: "Enseigne opening hours infra")
    @other_enseigne = @client.enseignes.create!(name: "Enseigne opening hours infra 2")
  end

  test "database rejects exact duplicate client opening hour for same day" do
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    end
  end

  test "database rejects overlapping client opening hours for same day after migration cleanup stops at exact duplicates" do
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "11:00", closes_at: "13:00")
    end
  end

  test "database accepts disjoint and contiguous client opening hours" do
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "12:00", closes_at: "14:00")
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "15:00", closes_at: "18:00")

    rows = select_opening_hours("client_opening_hours", "client_id", @client.id, 1)
    assert_equal 3, rows.length
  end

  test "database accepts same client opening hour on another client and another day" do
    insert_client_opening_hour(client_id: @client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: @other_client.id, day_of_week: 1, opens_at: "09:00", closes_at: "12:00")
    insert_client_opening_hour(client_id: @client.id, day_of_week: 2, opens_at: "09:00", closes_at: "12:00")

    assert_equal 1, select_opening_hours("client_opening_hours", "client_id", @other_client.id, 1).length
    assert_equal 1, select_opening_hours("client_opening_hours", "client_id", @client.id, 2).length
  end

  test "database rejects exact duplicate enseigne opening hour for same day" do
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "16:00")
    end
  end

  test "database rejects overlapping enseigne opening hours for same day after migration cleanup stops at exact duplicates" do
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "16:00")

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "15:00", closes_at: "18:00")
    end
  end

  test "database accepts disjoint and contiguous enseigne opening hours" do
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "12:00")
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "12:00", closes_at: "14:00")
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "15:00", closes_at: "18:00")

    rows = select_opening_hours("enseigne_opening_hours", "enseigne_id", @enseigne.id, 1)
    assert_equal 3, rows.length
  end

  test "database accepts same enseigne opening hour on another enseigne and another day" do
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "16:00")
    insert_enseigne_opening_hour(enseigne_id: @other_enseigne.id, day_of_week: 1, opens_at: "10:00", closes_at: "16:00")
    insert_enseigne_opening_hour(enseigne_id: @enseigne.id, day_of_week: 2, opens_at: "10:00", closes_at: "16:00")

    assert_equal 1, select_opening_hours("enseigne_opening_hours", "enseigne_id", @other_enseigne.id, 1).length
    assert_equal 1, select_opening_hours("enseigne_opening_hours", "enseigne_id", @enseigne.id, 2).length
  end

  private

  def insert_client_opening_hour(client_id:, day_of_week:, opens_at:, closes_at:)
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO client_opening_hours (client_id, day_of_week, opens_at, closes_at, created_at, updated_at)
      VALUES (#{client_id}, #{day_of_week}, '#{opens_at}', '#{closes_at}', NOW(), NOW())
    SQL
  end

  def insert_enseigne_opening_hour(enseigne_id:, day_of_week:, opens_at:, closes_at:)
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO enseigne_opening_hours (enseigne_id, day_of_week, opens_at, closes_at, created_at, updated_at)
      VALUES (#{enseigne_id}, #{day_of_week}, '#{opens_at}', '#{closes_at}', NOW(), NOW())
    SQL
  end

  def select_opening_hours(table_name, parent_column, parent_id, day_of_week)
    ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT opens_at::text, closes_at::text
      FROM #{table_name}
      WHERE #{parent_column} = #{parent_id}
        AND day_of_week = #{day_of_week}
      ORDER BY opens_at, closes_at
    SQL
  end
end
