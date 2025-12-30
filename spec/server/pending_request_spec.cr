require "../spec_helper"
require "../../src/server/pending_request"

describe Sellia::Server::PendingRequest do
  it "times out when no response is finished" do
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)

    pending = Sellia::Server::PendingRequest.new("id", context, "tunnel")

    pending.wait(10.milliseconds).should eq(false)
  end

  it "writes error status when response has not started" do
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)

    pending = Sellia::Server::PendingRequest.new("id", context, "tunnel")
    spawn { pending.error(504, "Gateway timeout") }

    pending.wait(1.second).should eq(true)
    context.response.status_code.should eq(504)
  end
end

describe Sellia::Server::PendingRequestStore do
  it "signals errors when removing requests by tunnel" do
    request = HTTP::Request.new("GET", "/")
    response = HTTP::Server::Response.new(IO::Memory.new)
    context = HTTP::Server::Context.new(request, response)

    pending = Sellia::Server::PendingRequest.new("id", context, "tunnel")
    store = Sellia::Server::PendingRequestStore.new(1.second)
    store.add(pending)

    store.remove_by_tunnel("tunnel").should eq(1)
    pending.wait(1.second).should eq(true)
    context.response.status_code.should eq(502)
  end
end
