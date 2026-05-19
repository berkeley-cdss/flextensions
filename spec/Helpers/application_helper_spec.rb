require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#google_oauth_enabled?' do
    around do |example|
      original_id     = ENV['GOOGLE_CLIENT_ID']
      original_secret = ENV['GOOGLE_CLIENT_SECRET']
      example.run
      ENV['GOOGLE_CLIENT_ID']     = original_id
      ENV['GOOGLE_CLIENT_SECRET'] = original_secret
    end

    it 'returns true when both Google OAuth env vars are set' do
      ENV['GOOGLE_CLIENT_ID']     = 'fake-id'
      ENV['GOOGLE_CLIENT_SECRET'] = 'fake-secret'
      expect(helper.google_oauth_enabled?).to be(true)
    end

    it 'returns false when GOOGLE_CLIENT_ID is missing' do
      ENV['GOOGLE_CLIENT_ID']     = nil
      ENV['GOOGLE_CLIENT_SECRET'] = 'fake-secret'
      expect(helper.google_oauth_enabled?).to be(false)
    end

    it 'returns false when GOOGLE_CLIENT_SECRET is missing' do
      ENV['GOOGLE_CLIENT_ID']     = 'fake-id'
      ENV['GOOGLE_CLIENT_SECRET'] = nil
      expect(helper.google_oauth_enabled?).to be(false)
    end

    it 'returns false when both env vars are blank' do
      ENV['GOOGLE_CLIENT_ID']     = ''
      ENV['GOOGLE_CLIENT_SECRET'] = ''
      expect(helper.google_oauth_enabled?).to be(false)
    end
  end
end
