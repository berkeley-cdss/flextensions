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

  describe '#delete' do
    let(:connection) { instance_double(Faraday::Connection) }
    let(:delete_request) { Struct.new(:headers).new({}) }

    before do
      client.instance_variable_set(:@conn, connection)
      client.instance_variable_set(:@csrf_token, 'csrf-token')
    end

    def stub_delete(status)
      allow(connection).to receive(:delete).with('/path').and_yield(delete_request).and_return(response_with(status))
    end

    it 'sends the CSRF token' do
      stub_delete(200)

      client.delete('/path')

      expect(delete_request.headers).to include('X-CSRF-Token' => 'csrf-token')
    end

    it 'accepts a redirect, which callers confirm by checking the record is gone' do
      stub_delete(302)

      expect(client.delete('/path')).to eq('body')
    end

    it 'raises on an error status' do
      stub_delete(403)

      expect { client.delete('/path') }.to raise_error(Lmss::Gradescope::AuthenticationError)
    end
  end
end
