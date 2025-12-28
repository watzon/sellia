require "./spec_helper"

describe Sellia do
  it "has version constant" do
    Sellia::VERSION.should_not be_nil
    Sellia::VERSION.should be_a(String)
  end
end
