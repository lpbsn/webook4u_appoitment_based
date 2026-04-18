class Admin::UsersController < Admin::BaseController
  before_action :load_client_user, only: %i[edit update toggle_active]
  before_action :load_clients, only: %i[new create edit update]

  def index
    redirect_to admin_clients_path(tab: :client_users)
  end

  def new
    @client_user = User.new(role: :client_user, active: true)
  end

  def create
    @client_user = User.new(client_user_params.merge(role: :client_user))

    if @client_user.save
      redirect_to admin_clients_path(tab: :client_users), notice: "Compte client créé."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attributes = client_user_params.dup
    strip_blank_password!(attributes)

    if @client_user.update(attributes)
      redirect_to admin_clients_path(tab: :client_users), notice: "Compte client mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @client_user.update!(active: !@client_user.active)
    redirect_to admin_clients_path(tab: :client_users), notice: "Statut du compte client mis à jour."
  end

  private

  def load_client_user
    @client_user = User.client_user.find(params[:id])
  end

  def load_clients
    @clients = Client.order(:name)
  end

  def client_user_params
    params.require(:user).permit(
      :client_id,
      :first_name,
      :last_name,
      :email,
      :password,
      :password_confirmation,
      :active
    )
  end

  def strip_blank_password!(attributes)
    return unless attributes[:password].blank? && attributes[:password_confirmation].blank?

    attributes.delete(:password)
    attributes.delete(:password_confirmation)
  end
end
