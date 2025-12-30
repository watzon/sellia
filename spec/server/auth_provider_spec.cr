require "../spec_helper"
require "../../src/server/auth_provider"

describe Sellia::Server::AuthProvider do
  it "accepts any key when auth is disabled" do
    provider = Sellia::Server::AuthProvider.new(require_auth: false)

    provider.validate("").should eq(true)
    provider.validate("any").should eq(true)
  end

  it "rejects empty keys when auth is required" do
    provider = Sellia::Server::AuthProvider.new(require_auth: true, master_key: "secret")

    provider.validate("").should eq(false)
  end

  it "validates against the master key when configured" do
    provider = Sellia::Server::AuthProvider.new(require_auth: true, master_key: "secret")

    provider.validate("secret").should eq(true)
    provider.validate("wrong").should eq(false)
  end

  it "accepts any non-empty key when no master key is set" do
    provider = Sellia::Server::AuthProvider.new(require_auth: true)

    provider.validate("abc").should eq(true)
  end

  it "generates a stable account id" do
    provider = Sellia::Server::AuthProvider.new

    id = provider.account_id_for("key")
    id.should eq(provider.account_id_for("key"))
    id.size.should eq(16)
  end
end
