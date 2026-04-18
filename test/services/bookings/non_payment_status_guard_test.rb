require "test_helper"

class Bookings::NonPaymentStatusGuardTest < ActiveSupport::TestCase
  test "non payment booking services do not transition bookings to failed" do
    service_dir = Rails.root.join("app/services/bookings")
    allowed_payment_files = %w[
      payment_failure_transition.rb
      transition_to_failed_from_payment.rb
    ]

    forbidden_patterns = [
      /booking_status:\s*:failed/,
      /booking_status\s*=\s*:failed/,
      /\.failed!\b/
    ]

    service_files = Dir.children(service_dir).select { |name| name.end_with?(".rb") }

    service_files.each do |service_file|
      next if allowed_payment_files.include?(service_file)

      content = File.read(service_dir.join(service_file))
      forbidden_patterns.each do |pattern|
        assert_no_match(
          pattern,
          content,
          "#{service_file} should not transition booking status to failed outside payment seam"
        )
      end
    end
  end
end
