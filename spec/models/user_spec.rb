# spec/models/user_spec.rb
# == Schema Information
#
# Table name: users
#
#  id         :bigint           not null, primary key
#  admin      :boolean          default(FALSE)
#  canvas_uid :string
#  email      :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  student_id :string
#
# Indexes
#
#  index_users_on_canvas_uid  (canvas_uid) UNIQUE
#  index_users_on_email       (email) UNIQUE
#
require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#canvas_credentials' do
    let(:user) { described_class.create!(email: 'test@example.com', canvas_uid: '123') }

    it 'returns the correct credentials for a user' do
      Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true }
      user.lms_credentials.create!(
        lms_id: 1,
        token: 'valid_token',
        refresh_token: 'refresh_token',
        expire_time: 1.hour.from_now
      )

      credentials = user.canvas_credentials
      expect(credentials).to be_an_instance_of(LmsCredential)
    end
  end

  describe '#ensure_fresh_canvas_token!' do
    let(:user) { described_class.create!(email: 'test@example.com', canvas_uid: '123') }

    context 'when the user has no credentials' do
      it 'returns nil' do
        expect(user.ensure_fresh_canvas_token!).to be_nil
      end
    end

    context 'when the user only has non-Canvas credentials' do
      before do
        other_lms = Lms.find_or_create_by(id: 2) { |lms| lms.lms_name = 'Gradescope'; lms.use_auth_token = false }
        user.lms_credentials.create!(
          lms_id: other_lms.id,
          token: 'other_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.from_now
        )
      end

      it 'returns nil' do
        expect(user.ensure_fresh_canvas_token!).to be_nil
      end
    end

    context 'when token does not expire soon' do
      before do
        Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true }
        user.lms_credentials.create!(
          lms_id: 1,
          token: 'valid_token',
          refresh_token: 'refresh_token',
          expire_time: 1.hour.from_now
        )
      end

      it 'returns the current token without refreshing' do
        expect_any_instance_of(LmsCredential).not_to receive(:refresh!)
        expect(user.ensure_fresh_canvas_token!).to eq('valid_token')
      end
    end

    context 'when token expires soon' do
      before do
        Lms.find_or_create_by(id: 1) { |lms| lms.lms_name = 'Canvas'; lms.use_auth_token = true }
        user.lms_credentials.create!(
          lms_id: 1,
          token: 'stale_token',
          refresh_token: 'refresh_token',
          expire_time: 5.minutes.from_now
        )
      end

      it 'refreshes the token and returns the new one' do
        allow_any_instance_of(LmsCredential).to receive(:refresh!).and_return('refreshed_token')

        expect(user.ensure_fresh_canvas_token!).to eq('refreshed_token')
      end

      it 'returns nil when the refresh fails, rather than a stale token' do
        allow_any_instance_of(LmsCredential).to receive(:refresh!).and_return(nil)

        expect(user.ensure_fresh_canvas_token!).to be_nil
      end
    end
  end
end
