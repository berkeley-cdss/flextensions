require 'rails_helper'

RSpec.describe Lmss::Gradescope::Client do
  # Build a client without running #initialize, which performs a live login.
  subject(:client) { described_class.allocate }

  def response_with(status)
    instance_double(Faraday::Response, status: status, body: 'body')
  end

  describe '#handle_response' do
    it 'returns the body for a successful response' do
      expect(client.send(:handle_response, response_with(200))).to eq('body')
    end

    it 'raises AuthenticationError for 401' do
      expect { client.send(:handle_response, response_with(401)) }
        .to raise_error(Lmss::Gradescope::AuthenticationError)
    end

    it 'raises AuthenticationError for 403' do
      expect { client.send(:handle_response, response_with(403)) }
        .to raise_error(Lmss::Gradescope::AuthenticationError)
    end

    it 'raises NotFoundError for 404' do
      expect { client.send(:handle_response, response_with(404)) }
        .to raise_error(Lmss::Gradescope::NotFoundError)
    end

    it 'raises RequestError for other error statuses' do
      expect { client.send(:handle_response, response_with(500)) }
        .to raise_error(Lmss::Gradescope::RequestError, /500/)
    end
  end
end
