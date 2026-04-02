require "test_helper"

load Rails.root.join("bin/setup") unless Object.private_method_defined?(:resolve_development_database_config)

class BinSetupDatabaseConfigResolutionTest < ActiveSupport::TestCase
  test "uses development yaml config as-is without DATABASE_URL" do
    raw_config = {
      "adapter" => "postgresql",
      "encoding" => "unicode",
      "max_connections" => 5,
      "database" => "webook4u_development"
    }

    resolved = resolve_development_database_config(raw_config)

    assert_equal raw_config, resolved
  end

  test "merges a complete DATABASE_URL over development yaml config" do
    raw_config = {
      "adapter" => "postgresql",
      "encoding" => "unicode",
      "max_connections" => 5,
      "database" => "webook4u_development"
    }

    resolved = resolve_development_database_config(
      raw_config,
      environment_url: "postgresql://demo_user:demo_pass@demo_host:6543/demo_db?pool=9"
    )

    assert_equal "postgresql", resolved["adapter"]
    assert_equal "unicode", resolved["encoding"]
    assert_equal 5, resolved["max_connections"]
    assert_equal "demo_db", resolved["database"]
    assert_equal "demo_host", resolved["host"]
    assert_equal 6543, resolved["port"]
    assert_equal "demo_user", resolved["username"]
    assert_equal "demo_pass", resolved["password"]
    assert_equal "9", resolved["pool"]
  end

  test "keeps yaml values not overridden by a partial DATABASE_URL" do
    raw_config = {
      "adapter" => "postgresql",
      "database" => "yaml_db",
      "host" => "yaml_host",
      "port" => 5432,
      "username" => "yaml_user",
      "max_connections" => 5
    }

    resolved = resolve_development_database_config(
      raw_config,
      environment_url: "postgresql:///env_db?pool=9"
    )

    assert_equal "postgresql", resolved["adapter"]
    assert_equal "env_db", resolved["database"]
    assert_equal "yaml_host", resolved["host"]
    assert_equal 5432, resolved["port"]
    assert_equal "yaml_user", resolved["username"]
    assert_equal 5, resolved["max_connections"]
    assert_equal "9", resolved["pool"]
  end

  test "merges development url first and then applies ENV DATABASE_URL overrides" do
    raw_config = {
      "adapter" => "postgresql",
      "encoding" => "unicode",
      "max_connections" => 5,
      "database" => "yaml_db",
      "host" => "yaml_host",
      "url" => "postgresql://url_user:url_pass@url_host:5433/url_db?pool=7"
    }

    resolved = resolve_development_database_config(
      raw_config,
      environment_url: "postgresql:///env_db?pool=9"
    )

    assert_equal "postgresql", resolved["adapter"]
    assert_equal "unicode", resolved["encoding"]
    assert_equal 5, resolved["max_connections"]
    assert_equal "env_db", resolved["database"]
    assert_equal "url_host", resolved["host"]
    assert_equal 5433, resolved["port"]
    assert_equal "url_user", resolved["username"]
    assert_equal "url_pass", resolved["password"]
    assert_equal "9", resolved["pool"]
    assert_not resolved.key?("url")
  end
end
