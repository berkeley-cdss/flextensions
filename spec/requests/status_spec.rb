require 'rails_helper'

RSpec.describe "Status", type: :request do
  describe "GET /status/health_check" do
    it "returns ok status and db connectivity" do
      get "/status/health_check"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["status"]).to eq("ok")
      expect(json["database"]).to be(true)
    end

    it "does not return ok when the database is unavailable" do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(StandardError, "database unavailable")

      get "/status/health_check"

      expect(response).to have_http_status(:internal_server_error)
      json = response.parsed_body
      expect(json["status"]).to eq("error")
      expect(json["database"]).to be(false)
      expect(json["error"]).to eq("database unavailable")
    end
  end

  describe "GET /status/version" do
    it "returns version, git info, deploy time, puma start time, and server time" do
      allow(DeploymentInfo).to receive_messages(commit: "abc123", deployed_at: Time.zone.now)
      allow_any_instance_of(StatusController).to receive(:fetch_puma_start_time).and_return(Time.zone.now)
      get "/status/version"
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["git_commit"]).to eq("abc123")
      expect(json["deployed_at"]).not_to be_nil
      expect(json["puma_start_time"]).not_to be_nil
      expect(json["server_time"]).not_to be_nil
    end
  end
end
