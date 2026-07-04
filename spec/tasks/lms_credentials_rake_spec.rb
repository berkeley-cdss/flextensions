require 'rails_helper'
require 'rake'

RSpec.describe 'lms_credentials:purge', type: :task do
  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    Rails.application.load_tasks unless Rake::Task.task_defined?('lms_credentials:purge')
  end

  let(:task) { Rake::Task['lms_credentials:purge'] }

  # Rake tasks only run once per process by default; re-enable between examples.
  after { task.reenable }

  def create_credential(email, lms_name)
    user = User.create!(email: email, canvas_uid: email)
    user.lms_credentials.create!(
      lms_name: lms_name,
      token: 'token',
      refresh_token: 'refresh_token',
      expire_time: 1.hour.from_now
    )
  end

  it 'deletes canvas credentials by default and leaves other LMS credentials alone' do
    canvas_credential = create_credential('canvas-user@example.com', 'canvas')
    other_credential = create_credential('other-user@example.com', 'other_lms')

    expect { task.invoke }.to output(/Deleted 1 canvas credential/).to_stdout

    expect(LmsCredential.exists?(canvas_credential.id)).to be false
    expect(LmsCredential.exists?(other_credential.id)).to be true
  end

  it 'purges the given LMS when a name is passed' do
    canvas_credential = create_credential('canvas-user2@example.com', 'canvas')
    other_credential = create_credential('other-user2@example.com', 'other_lms')

    expect { task.invoke('other_lms') }.to output(/Deleted 1 other_lms credential/).to_stdout

    expect(LmsCredential.exists?(other_credential.id)).to be false
    expect(LmsCredential.exists?(canvas_credential.id)).to be true
  end
end
