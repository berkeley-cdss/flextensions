# spec/models/lms_spec.rb
require 'rails_helper'

# == Schema Information
#
# Table name: lmss
#
#  id             :bigint           not null, primary key
#  lms_base_url   :string
#  lms_name       :string
#  use_auth_token :boolean
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
RSpec.describe Lms, type: :model do
  # Clear the in-memory cache around each example so tests exercise (and don't
  # leak) the preloaded state; other specs re-warm it lazily from the seed row.
  around do |example|
    described_class.instance_variable_set(:@canvas_lms, nil)
    described_class.instance_variable_set(:@gradescope_lms, nil)
    described_class.instance_variable_set(:@pensieve_lms, nil)
    example.run
    described_class.instance_variable_set(:@canvas_lms, nil)
    described_class.instance_variable_set(:@gradescope_lms, nil)
    described_class.instance_variable_set(:@pensieve_lms, nil)
  end

  describe '.preload!' do
    it 'returns the existing Canvas row without creating a duplicate' do
      expect { described_class.preload! }.not_to change(described_class, :count)
      expect(described_class.preload!).to eq(described_class.find(CANVAS_LMS_ID))
    end

    it 'creates the Canvas row with id 1 when it is missing' do
      described_class.where(id: CANVAS_LMS_ID).delete_all

      canvas = described_class.preload!

      expect(canvas.id).to eq(CANVAS_LMS_ID)
      expect(canvas.lms_name).to eq('Canvas')
      expect(canvas.use_auth_token).to be(true)
      expect(described_class.exists?(id: CANVAS_LMS_ID)).to be(true)
    end
  end

  describe '.CANVAS_LMS' do
    it 'serves the preloaded row from memory without querying the database' do
      preloaded = described_class.preload!

      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql].match?(/lmss/i)
      end
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        expect(described_class.CANVAS_LMS).to be(preloaded)
      end

      expect(queries).to be_empty
    end

    it 'falls back to loading the row when nothing is preloaded' do
      expect(described_class.CANVAS_LMS.id).to eq(CANVAS_LMS_ID)
    end
  end

  describe '.PENSIEVE_LMS' do
    it 'creates the Pensieve row with id 3 when it is missing' do
      CourseToLms.where(lms_id: PENSIEVE_LMS_ID).delete_all
      described_class.where(id: PENSIEVE_LMS_ID).delete_all

      pensieve = described_class.PENSIEVE_LMS

      expect(pensieve.id).to eq(PENSIEVE_LMS_ID)
      expect(pensieve.lms_name).to eq('Pensieve')
      expect(pensieve.lms_base_url).to eq('https://www.pensieve.co')
      expect(pensieve.use_auth_token).to be(false)
    end
  end

  describe '.facade_class' do
    it 'maps each known LMS id to its facade' do
      expect(described_class.facade_class(CANVAS_LMS_ID)).to eq(CanvasFacade)
      expect(described_class.facade_class(GRADESCOPE_LMS_ID)).to eq(GradescopeFacade)
      expect(described_class.facade_class(PENSIEVE_LMS_ID)).to eq(PensieveFacade)
    end

    it 'raises for an unknown LMS id' do
      expect { described_class.facade_class(999) }.to raise_error(/Unsupported LMS ID/)
    end
  end
end
