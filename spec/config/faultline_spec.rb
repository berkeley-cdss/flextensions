require 'rails_helper'

# The initializer in config/initializers/faultline.rb is the only place error
# notifications are wired up, so pin the parts the team relies on.
RSpec.describe 'Faultline configuration' do # rubocop:disable RSpec/DescribeClass
  let(:config) { Faultline.configuration }

  it 'emails the team about new errors' do
    email_notifiers = config.notifiers.select { |n| n.is_a?(Faultline::Notifiers::Email) }

    expect(email_notifiers.size).to eq(1)
    expect(email_notifiers.first.instance_variable_get(:@to)).to eq([ 'flextensions@berkeley.edu' ])
  end

  it 'notifies on first occurrence of an error group' do
    expect(config.notification_rules[:on_first_occurrence]).to be true
  end

  it 'subscribes to the Rails error reporter so job errors are tracked' do
    expect(config.register_error_subscriber).to be true
  end
end
