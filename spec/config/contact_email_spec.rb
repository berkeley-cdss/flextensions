require 'rails_helper'

# The support address users are pointed at in error messages lives in one
# place (config/application.rb) so it cannot drift between messages.
RSpec.describe 'Contact email configuration' do # rubocop:disable RSpec/DescribeClass
  it 'defaults to the Flextensions team mailbox' do
    expect(Rails.configuration.x.contact_email).to eq('flextensions@berkeley.edu')
  end
end
