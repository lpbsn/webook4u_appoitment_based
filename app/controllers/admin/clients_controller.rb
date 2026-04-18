class Admin::ClientsController < Admin::BaseController
  before_action :load_creation_step_context, only: %i[new create]
  helper_method :wizard_step_completed?

  WIZARD_SESSION_KEY = :admin_client_creation_wizard

  def index
    @active_tab = permitted_tab
    @clients = Client.order(:name)
    @client_users = User.client_user.includes(:client).order(:email)
  end

  def new
    if params[:restart].present?
      reset_wizard_draft!
      @draft = wizard_draft
    end

    target_step = [ @step, first_incomplete_step ].min
    if target_step != @step
      redirect_to new_admin_client_path(step: target_step)
      return
    end

    build_forms_for_step
  end

  def create
    @step_errors = []

    case @step
    when 1 then process_step_1!
    when 2 then process_step_2!
    when 3 then process_step_3!
    when 4 then process_step_4!
    else
      redirect_to new_admin_client_path(step: 1)
    end
  end

  def edit
    @client = Client.find(params[:id])
  end

  def update
    @client = Client.find(params[:id])

    if @client.update(client_params)
      redirect_to admin_clients_path(tab: :clients), notice: "Client mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_creation_step_context
    @step = normalize_step(params[:step] || params[:creation_step])
    @draft = wizard_draft
    @completed_steps = completed_steps_from_draft
  end

  def process_step_1!
    @client_form = Client.new(step_1_params)

    if @client_form.valid?
      @draft["client"] = step_1_params
      clear_following_steps!(from: 2)
      persist_wizard_draft!
      redirect_to new_admin_client_path(step: 2)
    else
      render_wizard_step(1)
    end
  end

  def process_step_2!
    enseignes = step_2_enseignes_params
    validate_step_2_requirements!(enseignes)

    if @step_errors.empty?
      @draft["enseignes"] = enseignes
      clear_following_steps!(from: 3)
      persist_wizard_draft!
      redirect_to new_admin_client_path(step: 3)
    else
      render_wizard_step(2)
    end
  end

  def process_step_3!
    @service_form = Service.new(step_3_service_params)
    validate_step_3_requirements!

    if @service_form.errors.empty? && @step_errors.empty?
      @draft["service_template"] = step_3_service_params
      clear_following_steps!(from: 4)
      persist_wizard_draft!
      redirect_to new_admin_client_path(step: 4)
    else
      render_wizard_step(3)
    end
  end

  def process_step_4!
    staffs = step_4_staffs_params
    validate_step_4_requirements!(staffs)

    if @step_errors.empty?
      @draft["staffs"] = staffs
      persist_wizard_draft!
      create_client_from_wizard_draft!
      reset_wizard_draft!
      redirect_to admin_clients_path(tab: :clients), notice: "Client créé avec son onboarding complet."
    else
      render_wizard_step(4)
    end
  end

  def create_client_from_wizard_draft!
    ActiveRecord::Base.transaction do
      client = Client.create!(@draft.fetch("client"))

      enseignes = @draft.fetch("enseignes").map do |enseigne_payload|
        opening_hours = enseigne_payload.delete("opening_hours")
        enseigne = client.enseignes.create!(enseigne_payload)
        opening_hours.each { |opening_hour| enseigne.enseigne_opening_hours.create!(opening_hour) }
        enseigne
      end

      services_by_enseigne = {}
      enseignes.each do |enseigne|
        service = enseigne.services.create!(@draft.fetch("service_template"))
        ServiceAssignmentCursor.find_or_create_by!(service: service)
        services_by_enseigne[enseigne.id] = service
      end

      @draft.fetch("staffs").each do |staff_payload|
        availabilities = staff_payload.delete("availabilities")
        enseigne_index = staff_payload.delete("enseigne_index")
        enseigne = enseignes.fetch(enseigne_index)

        staff = enseigne.staffs.create!(staff_payload)
        availabilities.each { |availability| staff.staff_availabilities.create!(availability) }
        StaffServiceCapability.find_or_create_by!(staff: staff, service: services_by_enseigne.fetch(enseigne.id))
      end
    end
  end

  def validate_step_2_requirements!(enseignes)
    if enseignes.blank?
      @step_errors << "Ajoutez au moins une enseigne."
      return
    end

    enseignes.each_with_index do |enseigne, index|
      if enseigne["name"].blank?
        @step_errors << "Enseigne ##{index + 1}: le nom est obligatoire."
      end
      if enseigne["full_address"].blank?
        @step_errors << "Enseigne ##{index + 1}: l'adresse est obligatoire."
      end

      opening_hours = enseigne["opening_hours"] || []
      if opening_hours.blank?
        @step_errors << "Enseigne ##{index + 1}: sélectionnez au moins un jour d'ouverture."
        next
      end

      opening_hours.each do |opening_hour|
        day = day_label(opening_hour["day_of_week"])
        if opening_hour["opens_at"].blank? || opening_hour["closes_at"].blank?
          @step_errors << "Enseigne ##{index + 1} (#{day}): renseignez 'ouvre à' et 'ferme à'."
          next
        end

        opens_value = Time.zone.parse(opening_hour["opens_at"].to_s)
        closes_value = Time.zone.parse(opening_hour["closes_at"].to_s)
        if opens_value.nil? || closes_value.nil?
          @step_errors << "Enseigne ##{index + 1} (#{day}): horaires invalides."
          next
        end

        unless opens_value < closes_value
          @step_errors << "Enseigne ##{index + 1} (#{day}): l'heure d'ouverture doit être avant l'heure de fermeture."
        end
      end
    end
  end

  def validate_step_3_requirements!
    duration = step_3_service_params["duration_minutes"].to_i
    price = step_3_service_params["price_cents"].to_i

    @step_errors << "La durée du service doit être strictement positive." unless duration.positive?
    @step_errors << "Le prix doit être positif ou nul." unless price >= 0
  end

  def validate_step_4_requirements!(staffs)
    if staffs.blank?
      @step_errors << "Ajoutez au moins un staff."
      return
    end

    staffs.each_with_index do |staff, index|
      if staff["name"].blank?
        @step_errors << "Staff ##{index + 1}: le nom est obligatoire."
      end
      if staff["enseigne_index"].nil?
        @step_errors << "Staff ##{index + 1}: sélectionnez une enseigne."
      end

      availabilities = staff["availabilities"] || []
      if availabilities.blank?
        @step_errors << "Staff ##{index + 1}: sélectionnez au moins un jour de disponibilité."
        next
      end

      availabilities.each do |availability|
        day = day_label(availability["day_of_week"])
        if availability["opens_at"].blank? || availability["closes_at"].blank?
          @step_errors << "Staff ##{index + 1} (#{day}): renseignez 'ouvre à' et 'ferme à'."
          next
        end

        opens_value = Time.zone.parse(availability["opens_at"].to_s)
        closes_value = Time.zone.parse(availability["closes_at"].to_s)
        if opens_value.nil? || closes_value.nil?
          @step_errors << "Staff ##{index + 1} (#{day}): horaires invalides."
          next
        end

        unless opens_value < closes_value
          @step_errors << "Staff ##{index + 1} (#{day}): l'heure de début doit être avant l'heure de fin."
        end
      end
    end
  end

  def render_wizard_step(step)
    @step = step
    build_forms_for_step
    render :new, status: :unprocessable_entity
  end

  def build_forms_for_step
    @step_errors ||= []
    @client_form = Client.new(@draft["client"] || {})
    @service_form = Service.new(@draft["service_template"] || {})
    @staff_form = Staff.new
    @enseignes_draft_entries = enseignes_entries_for_form
    @staffs_draft_entries = staffs_entries_for_form
  end

  def first_incomplete_step
    return 1 if @draft["client"].blank?
    return 2 if @draft["enseignes"].blank?
    return 3 if @draft["service_template"].blank?
    return 4 if @draft["staffs"].blank?

    4
  end

  def clear_following_steps!(from:)
    case from
    when 2
      @draft.delete("enseignes")
      @draft.delete("service_template")
      @draft.delete("staffs")
    when 3
      @draft.delete("service_template")
      @draft.delete("staffs")
    when 4
      @draft.delete("staffs")
    end
  end

  def wizard_draft
    session[WIZARD_SESSION_KEY] ||= {}
  end

  def persist_wizard_draft!
    session[WIZARD_SESSION_KEY] = @draft
  end

  def reset_wizard_draft!
    session.delete(WIZARD_SESSION_KEY)
  end

  def normalize_step(value)
    step = value.to_i
    return 1 if step < 1
    return 4 if step > 4

    step
  end

  def completed_steps_from_draft
    steps = []
    steps << 1 if @draft["client"].present?
    steps << 2 if @draft["enseignes"].present?
    steps << 3 if @draft["service_template"].present?
    steps
  end

  def wizard_step_completed?(wizard_step)
    @completed_steps.include?(wizard_step)
  end

  def enseignes_entries_for_form
    entries = @draft["enseignes"].presence || [ default_enseigne_entry(0) ]
    entries.each_with_index.map do |entry, index|
      normalized = entry.deep_dup
      normalized["ui_index"] = index
      normalized["opening_hours"] ||= []
      normalized
    end
  end

  def staffs_entries_for_form
    entries = @draft["staffs"].presence || [ default_staff_entry(0) ]
    entries.each_with_index.map do |entry, index|
      normalized = entry.deep_dup
      normalized["ui_index"] = index
      normalized["availabilities"] ||= []
      normalized["enseigne_index"] = normalized["enseigne_index"] || 0
      normalized
    end
  end

  def default_enseigne_entry(index)
    {
      "ui_index" => index,
      "name" => "",
      "full_address" => "",
      "active" => true,
      "opening_hours" => []
    }
  end

  def default_staff_entry(index)
    {
      "ui_index" => index,
      "name" => "",
      "active" => true,
      "enseigne_index" => 0,
      "availabilities" => []
    }
  end

  def step_1_params
    params.require(:client).permit(:name, :slug).to_h
  end

  def step_2_enseignes_params
    raw = params.fetch(:enseignes, ActionController::Parameters.new)
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h

    hash.values.map do |enseigne|
      opening_hours_hash = enseigne.fetch("opening_hours", {})
      opening_hours = opening_hours_hash.values.filter_map do |opening_hour|
        selected = ActiveModel::Type::Boolean.new.cast(opening_hour["selected"])
        next unless selected

        {
          "day_of_week" => opening_hour["day_of_week"].to_i,
          "opens_at" => opening_hour["opens_at"],
          "closes_at" => opening_hour["closes_at"]
        }
      end

      {
        "name" => enseigne["name"],
        "full_address" => enseigne["full_address"],
        "active" => ActiveModel::Type::Boolean.new.cast(enseigne["active"]),
        "opening_hours" => opening_hours
      }
    end
  end

  def step_3_service_params
    raw = params.require(:service).permit(:name, :duration_minutes, :price_cents).to_h
    raw["duration_minutes"] = raw["duration_minutes"].to_i if raw["duration_minutes"].present?
    raw["price_cents"] = raw["price_cents"].to_i if raw["price_cents"].present?
    raw
  end

  def step_4_staffs_params
    raw = params.fetch(:staffs, ActionController::Parameters.new)
    hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h

    hash.values.map do |staff|
      availabilities_hash = staff.fetch("availabilities", {})
      availabilities = availabilities_hash.values.filter_map do |availability|
        selected = ActiveModel::Type::Boolean.new.cast(availability["selected"])
        next unless selected

        {
          "day_of_week" => availability["day_of_week"].to_i,
          "opens_at" => availability["opens_at"],
          "closes_at" => availability["closes_at"]
        }
      end

      {
        "name" => staff["name"],
        "active" => ActiveModel::Type::Boolean.new.cast(staff["active"]),
        "enseigne_index" => (staff["enseigne_index"].presence&.to_i),
        "availabilities" => availabilities
      }
    end
  end

  def client_params
    params.require(:client).permit(:name, :slug)
  end

  def permitted_tab
    tab = params[:tab].to_s
    return "client_users" if tab == "client_users"

    "clients"
  end

  def day_label(raw_day)
    {
      0 => "Dimanche",
      1 => "Lundi",
      2 => "Mardi",
      3 => "Mercredi",
      4 => "Jeudi",
      5 => "Vendredi",
      6 => "Samedi"
    }[raw_day.to_i] || "-"
  end
end
