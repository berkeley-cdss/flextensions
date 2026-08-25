require 'rails_helper'

# GoodJob only records unhandled job exceptions on the job row in its
# dashboard; the on_thread_error hook is what forwards them to the Rails
# error reporter, and from there to subscribers like Faultline.
RSpec.describe 'GoodJob error reporting' do # rubocop:disable RSpec/DescribeClass
  it 'installs an on_thread_error hook' do
    expect(GoodJob.on_thread_error).to eq(Rails.application.config.good_job[:on_thread_error])
    expect(GoodJob.on_thread_error).to respond_to(:call)
  end

  it 'forwards unhandled job errors to the Rails error reporter' do
    error = StandardError.new('job blew up')
    allow(Rails.error).to receive(:report)

    GoodJob.on_thread_error.call(error)

    expect(Rails.error).to have_received(:report).with(error, handled: false, source: 'good_job')
  end
end
