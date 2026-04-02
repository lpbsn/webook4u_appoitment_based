class ServiceAssignmentCursor < ApplicationRecord
  belongs_to :service
  belongs_to :last_confirmed_staff, class_name: "Staff", optional: true

  validates :service_id, uniqueness: true

  def ordered_eligible_staffs
    service.staffs
           .where(active: true, enseigne_id: service.enseigne_id)
           .order(:id)
  end

  def eligible_staffs_in_rotation_order
    staffs = ordered_eligible_staffs.to_a
    return staffs if staffs.empty? || last_confirmed_staff_id.blank?

    first_index_after_cursor = staffs.index { |staff| staff.id > last_confirmed_staff_id } || 0
    staffs.rotate(first_index_after_cursor)
  end

  def next_eligible_staff
    eligible_staffs_in_rotation_order.first
  end
end
