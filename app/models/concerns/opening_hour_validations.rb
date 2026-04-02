# frozen_string_literal: true

module OpeningHourValidations
  extend ActiveSupport::Concern

  included do
    class_attribute :opening_hour_parent_key, instance_accessor: false

    validates :day_of_week, presence: true, inclusion: { in: 0..6 }
    validates :opens_at, presence: true
    validates :closes_at, presence: true

    validate :opens_at_before_closes_at
    validate :exact_interval_uniqueness_within_day
    validate :non_overlapping_interval_within_day
  end

  class_methods do
    def opening_hour_parent(name)
      belongs_to name
      self.opening_hour_parent_key = reflections.fetch(name.to_s).foreign_key
    end
  end

  private

  def opens_at_before_closes_at
    return if opens_at.blank? || closes_at.blank?
    return if opens_at < closes_at

    errors.add(:opens_at, "must be before closes_at")
  end

  def exact_interval_uniqueness_within_day
    return if incomplete_interval?
    return if sibling_hours_scope.blank?
    return unless sibling_hours_scope.where(opens_at: opens_at, closes_at: closes_at).exists?

    errors.add(:opens_at, "duplicates an existing opening hour for this day")
  end

  def non_overlapping_interval_within_day
    return if incomplete_interval?
    return if sibling_hours_scope.blank?
    return if errors.added?(:opens_at, "duplicates an existing opening hour for this day")

    return unless sibling_hours_scope.where("opens_at < ? AND closes_at > ?", closes_at, opens_at).exists?

    errors.add(:opens_at, "overlaps an existing opening hour for this day")
  end

  def sibling_hours_scope
    self.class
        .where(self.class.opening_hour_parent_key => parent_id_value, day_of_week: day_of_week)
        .where.not(id: id)
  end

  def parent_id_value
    public_send(self.class.opening_hour_parent_key)
  end

  def incomplete_interval?
    day_of_week.blank? || opens_at.blank? || closes_at.blank? || parent_id_value.blank?
  end
end
