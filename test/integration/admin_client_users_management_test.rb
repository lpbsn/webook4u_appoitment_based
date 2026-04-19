require "test_helper"

class AdminClientUsersManagementTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @client = clients(:one)
  end

  test "admin can create a client_user account" do
    sign_in @admin

    assert_difference("User.client_user.count", 1) do
      post admin_users_path, params: {
        user: {
          client_id: @client.id,
          first_name: "Client",
          last_name: "Manager",
          email: "client.manager@example.com",
          password: "password123",
          password_confirmation: "password123",
          active: "1"
        }
      }
    end

    created = User.find_by!(email: "client.manager@example.com")
    assert_equal "client_user", created.role
    assert_equal @client.id, created.client_id
    assert_redirected_to admin_clients_path(tab: :client_users)
  end

  test "admin can toggle client_user active status" do
    client_user = create_test_user(client: @client, role: :client_user, active: true)
    sign_in @admin

    patch toggle_active_admin_user_path(client_user)
    assert_redirected_to admin_clients_path(tab: :client_users)

    client_user.reload
    assert_not client_user.active?
  end

  test "non admin cannot access client users management" do
    non_admin = create_test_user(client: @client, role: :client_user, active: true)
    sign_in non_admin

    get admin_clients_path(tab: :client_users)
    assert_redirected_to client_root_path
  end

  test "admin can create a client through 4-step wizard" do
    sign_in @admin

    get new_admin_client_path(step: 1)
    assert_response :success

    post admin_clients_path, params: {
      creation_step: 1,
      client: {
        name: "Client Trois",
        slug: "client-trois"
      }
    }
    assert_redirected_to new_admin_client_path(step: 2)

    post admin_clients_path, params: {
      creation_step: 2,
      enseignes: {
        "0" => {
          name: "Enseigne Trois",
          address: "3 rue des tests",
          postal_code: "75001",
          city: "Paris",
          country: "France",
          active: "true",
          opening_hours: {
            "1" => {
              selected: "1",
              day_of_week: "1",
              opens_at: "09:00",
              closes_at: "18:00"
            }
          }
        }
      }
    }
    assert_redirected_to new_admin_client_path(step: 3)

    post admin_clients_path, params: {
      creation_step: 3,
      service: {
        name: "Coupe Trois",
        duration_minutes: "45",
        price_cents: "3500"
      }
    }
    assert_redirected_to new_admin_client_path(step: 4)

    assert_difference([ "Client.count", "Enseigne.count", "Service.count", "Staff.count", "StaffAvailability.count" ], 1) do
      post admin_clients_path, params: {
        creation_step: 4,
        staffs: {
          "0" => {
            name: "Emma Trois",
            active: "true",
            enseigne_index: "0",
            availabilities: {
              "1" => {
                selected: "1",
                day_of_week: "1",
                opens_at: "09:00",
                closes_at: "18:00"
              }
            }
          }
        }
      }
    end

    created = Client.find_by!(slug: "client-trois")
    assert_equal "Client Trois", created.name
    assert_redirected_to admin_clients_path(tab: :clients)
  end

  test "wizard step 2 is blocked if enseigne opening hour is incomplete" do
    sign_in @admin

    post admin_clients_path, params: {
      creation_step: 1,
      client: { name: "Client Blocage", slug: "client-blocage" }
    }
    assert_redirected_to new_admin_client_path(step: 2)

    post admin_clients_path, params: {
      creation_step: 2,
      enseignes: {
        "0" => {
          name: "Enseigne Blocage",
          address: "",
          postal_code: "",
          city: "",
          country: "",
          active: "true",
          opening_hours: {}
        }
      }
    }

    assert_response :unprocessable_entity
    assert_includes response.body, "Enseigne #1: l&#39;adresse est obligatoire."
    assert_includes response.body, "Enseigne #1: sélectionnez au moins un jour d&#39;ouverture."
  end

  test "clients index exposes two tabs" do
    sign_in @admin

    get admin_clients_path
    assert_response :success
    assert_includes response.body, "Liste des Clients"
    assert_includes response.body, "Liste des User Client"
    assert_includes response.body, "class=\"booking-back-link\""
    assert_includes response.body, "href=\"#{admin_root_path}\""
  end

  test "new client wizard back link always points to clients index" do
    sign_in @admin

    get new_admin_client_path(step: 1)
    assert_response :success
    assert_includes response.body, "class=\"booking-back-link\""
    assert_includes response.body, "href=\"#{admin_clients_path}\""

    post admin_clients_path, params: {
      creation_step: 1,
      client: { name: "Client Back Link", slug: "client-back-link" }
    }
    assert_redirected_to new_admin_client_path(step: 2)

    get new_admin_client_path(step: 2)
    assert_response :success
    assert_includes response.body, "href=\"#{admin_clients_path}\""
  end

  test "new client user back link points to clients index" do
    sign_in @admin

    get new_admin_user_path
    assert_response :success
    assert_includes response.body, "class=\"booking-back-link\""
    assert_includes response.body, "href=\"#{admin_clients_path}\""
  end
  test "wizard step 4 shows enseigne address formatted without country" do
    sign_in @admin

    post admin_clients_path, params: {
      creation_step: 1,
      client: {
        name: "Client Trois",
        slug: "client-trois"
      }
    }
    assert_redirected_to new_admin_client_path(step: 2)

    post admin_clients_path, params: {
      creation_step: 2,
      enseignes: {
        "0" => {
          name: "Enseigne Trois",
          address: "3 rue des tests",
          postal_code: "75001",
          city: "Paris",
          country: "France",
          active: "true",
          opening_hours: {
            "1" => {
              selected: "1",
              day_of_week: "1",
              opens_at: "09:00",
              closes_at: "18:00"
            }
          }
        }
      }
    }
  end
end
