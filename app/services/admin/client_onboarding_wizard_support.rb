# frozen_string_literal: true

module Admin
  class ClientOnboardingWizardSupport
    DAY_LABELS = {
      0 => "Dimanche",
      1 => "Lundi",
      2 => "Mardi",
      3 => "Mercredi",
      4 => "Jeudi",
      5 => "Vendredi",
      6 => "Samedi"
    }.freeze

    def validate_enseignes(enseignes)
      errors = []
      if enseignes.blank?
        errors << "Ajoutez au moins une enseigne."
        return errors
      end

      enseignes.each_with_index do |enseigne, index|
        errors << "Enseigne ##{index + 1}: le nom est obligatoire." if enseigne["name"].blank?
        errors << "Enseigne ##{index + 1}: l'adresse est obligatoire." if enseigne["full_address"].blank?

        opening_hours = enseigne["opening_hours"] || []
        if opening_hours.blank?
          errors << "Enseigne ##{index + 1}: sélectionnez au moins un jour d'ouverture."
          next
        end

        opening_hours.each do |opening_hour|
          day = day_label(opening_hour["day_of_week"])
          if opening_hour["opens_at"].blank? || opening_hour["closes_at"].blank?
            errors << "Enseigne ##{index + 1} (#{day}): renseignez 'ouvre à' et 'ferme à'."
            next
          end

          opens_value = Time.zone.parse(opening_hour["opens_at"].to_s)
          closes_value = Time.zone.parse(opening_hour["closes_at"].to_s)
          if opens_value.nil? || closes_value.nil?
            errors << "Enseigne ##{index + 1} (#{day}): horaires invalides."
            next
          end

          unless opens_value < closes_value
            errors << "Enseigne ##{index + 1} (#{day}): l'heure d'ouverture doit être avant l'heure de fermeture."
          end
        end
      end

      errors
    end

    def validate_service_template(service_form:, service_params:)
      errors = []
      duration = service_params["duration_minutes"].to_i
      price = service_params["price_cents"].to_i

      errors << "La durée du service doit être strictement positive." unless duration.positive?
      errors << "Le prix doit être positif ou nul." unless price >= 0

      if service_form.name.blank?
        service_form.errors.add(:name, :blank)
      end

      errors
    end

    def validate_staffs(staffs)
      errors = []
      if staffs.blank?
        errors << "Ajoutez au moins un staff."
        return errors
      end

      staffs.each_with_index do |staff, index|
        errors << "Staff ##{index + 1}: le nom est obligatoire." if staff["name"].blank?
        errors << "Staff ##{index + 1}: sélectionnez une enseigne." if staff["enseigne_index"].nil?

        availabilities = staff["availabilities"] || []
        if availabilities.blank?
          errors << "Staff ##{index + 1}: sélectionnez au moins un jour de disponibilité."
          next
        end

        availabilities.each do |availability|
          day = day_label(availability["day_of_week"])
          if availability["opens_at"].blank? || availability["closes_at"].blank?
            errors << "Staff ##{index + 1} (#{day}): renseignez 'ouvre à' et 'ferme à'."
            next
          end

          opens_value = Time.zone.parse(availability["opens_at"].to_s)
          closes_value = Time.zone.parse(availability["closes_at"].to_s)
          if opens_value.nil? || closes_value.nil?
            errors << "Staff ##{index + 1} (#{day}): horaires invalides."
            next
          end

          unless opens_value < closes_value
            errors << "Staff ##{index + 1} (#{day}): l'heure de début doit être avant l'heure de fin."
          end
        end
      end

      errors
    end

    def create_client_from_wizard_draft!(draft:)
      ActiveRecord::Base.transaction do
        client = Client.create!(draft.fetch("client"))

        enseignes = draft.fetch("enseignes").map do |enseigne_payload|
          enseigne_data = enseigne_payload.deep_dup
          opening_hours = enseigne_data.delete("opening_hours")

          enseigne = client.enseignes.create!(enseigne_data)
          opening_hours.each { |opening_hour| enseigne.enseigne_opening_hours.create!(opening_hour) }
          enseigne
        end

        services_by_enseigne = {}
        enseignes.each do |enseigne|
          service = enseigne.services.create!(draft.fetch("service_template"))
          ServiceAssignmentCursor.find_or_create_by!(service: service)
          services_by_enseigne[enseigne.id] = service
        end

        draft.fetch("staffs").each do |staff_payload|
          staff_data = staff_payload.deep_dup
          availabilities = staff_data.delete("availabilities")
          enseigne_index = staff_data.delete("enseigne_index")
          enseigne = enseignes.fetch(enseigne_index)

          staff = enseigne.staffs.create!(staff_data)
          availabilities.each { |availability| staff.staff_availabilities.create!(availability) }
          StaffServiceCapability.find_or_create_by!(staff: staff, service: services_by_enseigne.fetch(enseigne.id))
        end
      end
    end

    private

    def day_label(raw_day)
      DAY_LABELS[raw_day.to_i] || "-"
    end
  end
end
