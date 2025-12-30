require "../../spec_helper"
require "../../../src/server/storage/storage"

describe Sellia::Server::Storage do
  describe "Repositories" do
    before_each do
      SpecHelper.reset_db(keep_defaults: false)
    end

    describe "ReservedSubdomains" do
      it "seeds default reserved subdomains" do
        Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains

        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("api").should be_true
        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("www").should be_true
        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("admin").should be_true
      end

      it "checks if subdomain exists" do
        Sellia::Server::Storage::Repositories::ReservedSubdomains.create("custom", "Custom reserved")

        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("custom").should be_true
        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("nonexistent").should be_false
      end

      it "returns all reserved subdomains as a set" do
        Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains
        Sellia::Server::Storage::Repositories::ReservedSubdomains.create("custom")

        set = Sellia::Server::Storage::Repositories::ReservedSubdomains.to_set
        set.should contain("api")
        set.should contain("custom")
      end

      it "deletes reserved subdomain" do
        Sellia::Server::Storage::Repositories::ReservedSubdomains.create("temporary")

        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("temporary").should be_true

        Sellia::Server::Storage::Repositories::ReservedSubdomains.delete("temporary").should be_true
        Sellia::Server::Storage::Repositories::ReservedSubdomains.exists?("temporary").should be_false
      end

      it "returns false when deleting non-existent subdomain" do
        Sellia::Server::Storage::Repositories::ReservedSubdomains.delete("nonexistent").should be_false
      end

      it "lists all reserved subdomains" do
        Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains

        all = Sellia::Server::Storage::Repositories::ReservedSubdomains.all
        all.size.should be > 40

        api_reserved = all.find { |r| r.subdomain == "api" }
        api_reserved.should_not be_nil
        api_reserved.not_nil!.is_default.should be_true
      end
    end

    describe "ApiKeys" do
      it "creates and validates API key" do
        plaintext = "test_api_key_12345678"

        api_key = Sellia::Server::Storage::Repositories::ApiKeys.create(
          plaintext,
          name: "Test Key"
        )

        api_key.key_prefix.should eq(plaintext[0, 8])

        found = Sellia::Server::Storage::Repositories::ApiKeys.validate(plaintext)
        found.should_not be_nil
        found.not_nil!.key_prefix.should eq("test_api")
        found.not_nil!.name.should eq("Test Key")
      end

      it "does not validate invalid key" do
        Sellia::Server::Storage::Repositories::ApiKeys.validate("invalid").should be_nil
      end

      it "validates against key hash" do
        plaintext = "test_key_for_hashing"
        key = Sellia::Server::Storage::Repositories::ApiKeys.create(plaintext)

        expected_hash = Sellia::Server::Storage::Models::ApiKey.hash_key(plaintext)
        key.key_hash.should eq(expected_hash)
      end

      it "finds keys by prefix" do
        Sellia::Server::Storage::Repositories::ApiKeys.create("abcd1234_test_key")
        Sellia::Server::Storage::Repositories::ApiKeys.create("abcd5678_another_key")

        results = Sellia::Server::Storage::Repositories::ApiKeys.find_by_prefix("abcd")
        results.size.should be >= 2
      end

      it "updates last_used_at on validation" do
        plaintext = "test_key_for_last_used"
        key = Sellia::Server::Storage::Repositories::ApiKeys.create(plaintext)

        # Find the key to get its ID
        found = Sellia::Server::Storage::Repositories::ApiKeys.validate(plaintext)
        found.should_not be_nil
        found.not_nil!.last_used_at.should_not be_nil
      end

      it "creates master key" do
        plaintext = "master_key_12345678"

        api_key = Sellia::Server::Storage::Repositories::ApiKeys.create(
          plaintext,
          name: "Master Key",
          is_master: true
        )

        api_key.is_master.should be_true
      end

      it "revokes API key" do
        plaintext = "key_to_revoke_123456"
        key = Sellia::Server::Storage::Repositories::ApiKeys.create(plaintext)

        # Initially valid
        Sellia::Server::Storage::Repositories::ApiKeys.validate(plaintext).should_not be_nil

        # Revoke
        Sellia::Server::Storage::Repositories::ApiKeys.revoke(key.key_prefix).should be_true

        # No longer valid
        Sellia::Server::Storage::Repositories::ApiKeys.validate(plaintext).should be_nil
      end

      it "returns false when revoking non-existent key" do
        Sellia::Server::Storage::Repositories::ApiKeys.revoke("nonexistent").should be_false
      end

      it "counts active API keys" do
        Sellia::Server::Storage::Repositories::ApiKeys.create("key1_12345678")
        Sellia::Server::Storage::Repositories::ApiKeys.create("key2_12345678")

        count = Sellia::Server::Storage::Repositories::ApiKeys.count_active
        count.should eq(2)
      end

      it "returns all API keys" do
        Sellia::Server::Storage::Repositories::ApiKeys.create("key1_12345678", name: "Key 1")
        Sellia::Server::Storage::Repositories::ApiKeys.create("key2_12345678", name: "Key 2")

        all = Sellia::Server::Storage::Repositories::ApiKeys.all
        all.size.should eq(2)
      end
    end
  end
end
