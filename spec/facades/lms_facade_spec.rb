require 'rails_helper'

describe LmsFacade do
  let(:facade) { described_class.new }
  let(:mock_course) { 16 }
  let(:mock_student) { 22 }
  let(:mock_assignment) { 18 }
  let(:mock_date) { '2002-03-16:16:00:00Z' }

  describe 'provision_extension' do
    it 'throws not implemented error' do
      expect do
        facade.provision_extension(
          mock_course,
          mock_student,
          mock_assignment,
          mock_date
        )
      end.to raise_error(NotImplementedError)
    end
  end

  describe '.assignment_url' do
    it 'throws not implemented error' do
      expect do
        described_class.assignment_url('https://lms.example', mock_course, mock_assignment)
      end.to raise_error(NotImplementedError)
    end
  end
end
