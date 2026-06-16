# frozen_string_literal: true

require "rails_helper"

RSpec.describe GrokService do
  subject(:result) { described_class.call(grokable: grokable, messages: messages, tools: tools) }

  let(:grokable) do
    user = User.create!(username: "alice", password: "password123", password_confirmation: "password123")
    user.worlds.create!(title: "Aerth", core_concept: "A world of floating islands.")
  end
  let(:messages) { [{ role: "user", content: "Hello" }] }
  let(:tools) { [{ type: "function", function: { name: "ping" } }] }
  let(:http_response) { instance_double(Net::HTTPResponse, body: response_body.to_json, code: "200") }

  def response_body
    { "id" => "1", "choices" => [{ "message" => { "content" => "Hi" } }] }
  end

  before do
    allow(Net::HTTP).to receive(:start).and_return(http_response)
  end

  describe ".call" do
    it "returns the parsed response body" do
      expect(result).to eq(response_body)
    end

    it "persists a GrokCall record" do
      expect { result }.to change(GrokCall, :count).by(1)
    end

    it "stores the request payload" do
      result
      expect(GrokCall.last.payload).to include(
        "model" => described_class::MODEL,
        "messages" => messages.map(&:stringify_keys),
      )
    end

    it "stores the tools in the payload" do
      result
      expect(GrokCall.last.payload["tools"]).to eq(tools.map(&:deep_stringify_keys))
    end

    it "stores the response body" do
      result
      expect(GrokCall.last.response).to eq(response_body)
    end

    it "stores the HTTP status code" do
      result
      expect(GrokCall.last.status).to eq(200)
    end

    it "associates the call with the grokable record" do
      result
      expect(GrokCall.last.grokable).to eq(grokable)
    end

    context "when no tools are given" do
      subject(:result) { described_class.call(grokable: grokable, messages: messages) }

      it "omits tools from the payload" do
        result
        expect(GrokCall.last.payload).not_to have_key("tools")
      end
    end

    context "when the response body is not valid JSON" do
      let(:http_response) { instance_double(Net::HTTPResponse, body: "not json", code: "500") }

      it "returns nil" do
        expect(result).to be_nil
      end

      it "persists the call with a nil response" do
        result
        expect(GrokCall.last.response).to be_nil
      end
    end
  end
end
