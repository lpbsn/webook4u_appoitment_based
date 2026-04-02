require "test_helper"

load Rails.root.join("bin/setup") unless Object.private_method_defined?(:verify_postgres!)

class BinSetupPreflightTest < ActiveSupport::TestCase
  test "ruby preflight fails when active version does not match the repo contract" do
    error = assert_preflight_failure("Ruby 9.9.9 is required") do
      with_method_override(:expected_ruby_version, "9.9.9") do
        verify_ruby!
      end
    end

    assert_includes error.message, "Switch Ruby to 9.9.9"
  end

  test "bundler preflight fails when the active version is incompatible" do
    output = "Bundler version 2.6.0"

    error = assert_preflight_failure("Bundler 2.7.2 is required") do
      with_method_override(:expected_bundler_version, "2.7.2") do
        with_method_override(:capture!, [ output, success_status ]) do
          verify_bundler!
        end
      end
    end

    assert_includes error.message, "gem install bundler:2.7.2"
  end

  test "postgres preflight succeeds for a reachable supported server" do
    config = {
      "adapter" => "postgresql",
      "database" => "webook4u_development"
    }

    with_method_override(:development_database_config, config) do
      with_method_override(:capture!, [ "17.4|170004", success_status ]) do
        assert_nil verify_postgres!
      end
    end
  end

  test "postgres preflight fails when the server is not reachable" do
    config = {
      "adapter" => "postgresql",
      "database" => "webook4u_development"
    }

    error = assert_preflight_failure("Cannot reach the PostgreSQL server") do
      with_method_override(:development_database_config, config) do
        with_method_override(:capture!, [ "psql: error: connection failed", failure_status ]) do
          verify_postgres!
        end
      end
    end

    assert_includes error.message, "Start PostgreSQL 17.x locally"
  end

  test "postgres preflight fails when the reachable server major is unsupported" do
    config = {
      "adapter" => "postgresql",
      "database" => "webook4u_development"
    }

    error = assert_preflight_failure("PostgreSQL server 16.9 is connected") do
      with_method_override(:development_database_config, config) do
        with_method_override(:capture!, [ "16.9|160009", success_status ]) do
          verify_postgres!
        end
      end
    end

    assert_includes error.message, "17.x is required"
  end

  test "postgres preflight fails when development config resolution is invalid" do
    invalid_uri_error = URI::InvalidURIError.new("bad URI")

    error = assert_preflight_failure("Cannot resolve the development PostgreSQL config") do
      with_method_override(:development_database_config, -> { raise invalid_uri_error }) do
        verify_postgres!
      end
    end

    assert_includes error.message, "bad URI"
  end

  private

  def assert_preflight_failure(expected_message)
    error = assert_raises(RuntimeError) do
      with_method_override(:abort_setup!, ->(message) { raise RuntimeError, message }) do
        yield
      end
    end

    assert_includes error.message, expected_message
    error
  end

  def with_method_override(method_name, replacement)
    singleton_class.define_method(method_name) do |*args, **kwargs, &block|
      if replacement.respond_to?(:call)
        replacement.call(*args, **kwargs, &block)
      else
        replacement
      end
    end
    singleton_class.send(:private, method_name)

    yield
  ensure
    singleton_class.send(:remove_method, method_name)
  end

  def success_status
    Status.new(true)
  end

  def failure_status
    Status.new(false)
  end

  Status = Struct.new(:result) do
    def success?
      result
    end
  end
end
