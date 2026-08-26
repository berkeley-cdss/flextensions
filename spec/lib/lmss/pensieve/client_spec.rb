require 'rails_helper'

RSpec.describe Lmss::Pensieve::Client do
  subject(:client) { described_class.new('test-token') }

  let(:grant_url) { "#{described_class::BASE_URL}#{described_class::GRANT_EXTENSION_PATH}" }
  let(:list_url) { "#{described_class::BASE_URL}#{described_class::LIST_ASSIGNMENTS_PATH}" }

  describe '#initialize' do
    it 'raises AuthenticationError without a token' do
      expect { described_class.new(nil) }.to raise_error(Lmss::Pensieve::AuthenticationError)
      expect { described_class.new('') }.to raise_error(Lmss::Pensieve::AuthenticationError)
    end
  end

  describe '#grant_extension' do
    it 'posts the assignment URL, student email, and days with the bearer token' do
      stub = stub_request(:post, grant_url)
             .with(
               headers: { 'Authorization' => 'Bearer test-token' },
               body: {
                 assignment_url: 'https://www.pensieve.co/assignments/1',
                 student_email: 'student@example.com',
                 num_days: 2
               }.to_json
             )
             .to_return(status: 200, body: { success: true }.to_json,
                        headers: { 'Content-Type' => 'application/json' })

      result = client.grant_extension(
        assignment_url: 'https://www.pensieve.co/assignments/1',
        student_email: 'student@example.com',
        num_days: 2
      )

      expect(stub).to have_been_requested
      expect(result).to eq({ 'success' => true })
    end

    it 'raises RequestError when Pensieve responds 200 without success' do
      stub_request(:post, grant_url)
        .to_return(status: 200, body: { success: false, error: 'nope' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect do
        client.grant_extension(assignment_url: 'a', student_email: 'b', num_days: 1)
      end.to raise_error(Lmss::Pensieve::RequestError, /did not grant/)
    end

    it 'raises AuthenticationError for 401 responses' do
      stub_request(:post, grant_url).to_return(status: 401)

      expect do
        client.grant_extension(assignment_url: 'a', student_email: 'b', num_days: 1)
      end.to raise_error(Lmss::Pensieve::AuthenticationError)
    end

    it 'raises RequestError for server errors' do
      stub_request(:post, grant_url).to_return(status: 500)

      expect do
        client.grant_extension(assignment_url: 'a', student_email: 'b', num_days: 1)
      end.to raise_error(Lmss::Pensieve::RequestError, /500/)
    end
  end

  describe '#list_assignments' do
    it 'returns the assignments array from a wrapped response' do
      stub_request(:get, list_url)
        .with(query: { course_url: 'https://www.pensieve.co/courses/1' })
        .to_return(status: 200,
                   body: { success: true, assignments: [ { 'url' => 'x' } ] }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(client.list_assignments('https://www.pensieve.co/courses/1')).to eq([ { 'url' => 'x' } ])
    end

    it 'returns a bare array response as-is' do
      stub_request(:get, list_url)
        .with(query: { course_url: 'c' })
        .to_return(status: 200, body: [ { 'url' => 'x' } ].to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(client.list_assignments('c')).to eq([ { 'url' => 'x' } ])
    end

    it 'raises NotFoundError while Pensieve has not published the endpoint' do
      stub_request(:get, list_url).with(query: { course_url: 'c' }).to_return(status: 404)

      expect { client.list_assignments('c') }.to raise_error(Lmss::Pensieve::NotFoundError)
    end
  end
end
