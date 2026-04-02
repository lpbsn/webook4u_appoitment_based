class HardenOpeningHoursConstraints < ActiveRecord::Migration[8.1]
  CLIENT_CHECK_CONSTRAINT = "client_opening_hours_opens_before_closes"
  ENSEIGNE_CHECK_CONSTRAINT = "enseigne_opening_hours_opens_before_closes"
  CLIENT_EXACT_INDEX = "index_client_opening_hours_on_exact_interval_per_day"
  ENSEIGNE_EXACT_INDEX = "index_enseigne_opening_hours_on_exact_interval_per_day"
  CLIENT_OVERLAP_CONSTRAINT = "client_opening_hours_no_overlapping_intervals_per_day"
  ENSEIGNE_OVERLAP_CONSTRAINT = "enseigne_opening_hours_no_overlapping_intervals_per_day"

  def up
    enable_extension "btree_gist"

    # Strategy retained for weekly opening hours:
    # - exact duplicates are removed automatically
    # - non-trivial overlaps are never merged implicitly
    # - migration aborts with a diagnostic until remaining overlaps are fixed manually
    deduplicate_exact_intervals!("client_opening_hours", "client_id")
    deduplicate_exact_intervals!("enseigne_opening_hours", "enseigne_id")

    assert_no_non_trivial_overlaps!("client_opening_hours", "client_id")
    assert_no_non_trivial_overlaps!("enseigne_opening_hours", "enseigne_id")

    add_check_constraint :client_opening_hours, "opens_at < closes_at", name: CLIENT_CHECK_CONSTRAINT
    add_check_constraint :enseigne_opening_hours, "opens_at < closes_at", name: ENSEIGNE_CHECK_CONSTRAINT

    add_index :client_opening_hours,
              [ :client_id, :day_of_week, :opens_at, :closes_at ],
              unique: true,
              name: CLIENT_EXACT_INDEX
    add_index :enseigne_opening_hours,
              [ :enseigne_id, :day_of_week, :opens_at, :closes_at ],
              unique: true,
              name: ENSEIGNE_EXACT_INDEX

    execute <<~SQL
      ALTER TABLE client_opening_hours
      ADD CONSTRAINT #{CLIENT_OVERLAP_CONSTRAINT}
      EXCLUDE USING gist (
        client_id WITH =,
        day_of_week WITH =,
        int4range(
          EXTRACT(EPOCH FROM opens_at)::integer,
          EXTRACT(EPOCH FROM closes_at)::integer,
          '[)'
        ) WITH &&
      );
    SQL

    execute <<~SQL
      ALTER TABLE enseigne_opening_hours
      ADD CONSTRAINT #{ENSEIGNE_OVERLAP_CONSTRAINT}
      EXCLUDE USING gist (
        enseigne_id WITH =,
        day_of_week WITH =,
        int4range(
          EXTRACT(EPOCH FROM opens_at)::integer,
          EXTRACT(EPOCH FROM closes_at)::integer,
          '[)'
        ) WITH &&
      );
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE client_opening_hours
      DROP CONSTRAINT IF EXISTS #{CLIENT_OVERLAP_CONSTRAINT};
    SQL

    execute <<~SQL
      ALTER TABLE enseigne_opening_hours
      DROP CONSTRAINT IF EXISTS #{ENSEIGNE_OVERLAP_CONSTRAINT};
    SQL

    remove_index :client_opening_hours, name: CLIENT_EXACT_INDEX if index_exists?(:client_opening_hours, name: CLIENT_EXACT_INDEX)
    remove_index :enseigne_opening_hours, name: ENSEIGNE_EXACT_INDEX if index_exists?(:enseigne_opening_hours, name: ENSEIGNE_EXACT_INDEX)

    remove_check_constraint :client_opening_hours, name: CLIENT_CHECK_CONSTRAINT
    remove_check_constraint :enseigne_opening_hours, name: ENSEIGNE_CHECK_CONSTRAINT
  end

  private

  def deduplicate_exact_intervals!(table_name, parent_column)
    execute <<~SQL
      WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (
                 PARTITION BY #{parent_column}, day_of_week, opens_at, closes_at
                 ORDER BY id
               ) AS row_rank
        FROM #{table_name}
      )
      DELETE FROM #{table_name} rows_to_delete
      USING ranked
      WHERE rows_to_delete.id = ranked.id
        AND ranked.row_rank > 1;
    SQL
  end

  def assert_no_non_trivial_overlaps!(table_name, parent_column)
    overlap_count = ActiveRecord::Base.connection.select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM #{table_name} left_rows
      JOIN #{table_name} right_rows
        ON left_rows.id < right_rows.id
       AND left_rows.#{parent_column} = right_rows.#{parent_column}
       AND left_rows.day_of_week = right_rows.day_of_week
       AND left_rows.opens_at < right_rows.closes_at
       AND left_rows.closes_at > right_rows.opens_at
       AND NOT (
         left_rows.opens_at = right_rows.opens_at
         AND left_rows.closes_at = right_rows.closes_at
       )
    SQL

    return if overlap_count.zero?

    sample_rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
      SELECT
        left_rows.id,
        right_rows.id,
        left_rows.#{parent_column},
        left_rows.day_of_week,
        left_rows.opens_at::text,
        left_rows.closes_at::text,
        right_rows.opens_at::text,
        right_rows.closes_at::text
      FROM #{table_name} left_rows
      JOIN #{table_name} right_rows
        ON left_rows.id < right_rows.id
       AND left_rows.#{parent_column} = right_rows.#{parent_column}
       AND left_rows.day_of_week = right_rows.day_of_week
       AND left_rows.opens_at < right_rows.closes_at
       AND left_rows.closes_at > right_rows.opens_at
       AND NOT (
         left_rows.opens_at = right_rows.opens_at
         AND left_rows.closes_at = right_rows.closes_at
       )
      ORDER BY left_rows.#{parent_column}, left_rows.day_of_week, left_rows.opens_at, right_rows.opens_at
      LIMIT 10
    SQL

    diagnostic = sample_rows.map do |left_id, right_id, parent_id, day_of_week, left_opens, left_closes, right_opens, right_closes|
      "#{parent_column}=#{parent_id} day=#{day_of_week} left_id=#{left_id} (#{left_opens}-#{left_closes}) "\
        "right_id=#{right_id} (#{right_opens}-#{right_closes})"
    end.join("; ")

    raise <<~MSG.squish
      Cannot add opening hours overlap constraints on #{table_name}:
      exact duplicates are cleaned automatically, but #{overlap_count} non-trivial overlap pair(s) remain.
      These overlaps are not merged automatically by this migration.
      Sample: #{diagnostic}
      Please fix these rows manually before rerunning this migration.
    MSG
  end
end
