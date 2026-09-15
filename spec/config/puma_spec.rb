require 'rails_helper'
require 'puma/configuration'

# Elastic Beanstalk's nginx only proxies to a Unix socket, so the socket bind
# has to hold regardless of worker count. Binding on TCP 3000 in single mode
# once turned a missing WEB_CONCURRENCY into 502s, failed health checks and a
# rolled-back deployment.
RSpec.describe 'config/puma.rb' do # rubocop:disable RSpec/DescribeClass
  # Loads the config the way `puma -C config/puma.rb` does and returns the
  # finalized options.
  def puma_options(env: {}, on_elastic_beanstalk: false)
    stub_const('ENV', ENV.to_h.except('WEB_CONCURRENCY', 'PORT', 'PIDFILE').merge(env))
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with('/opt/elasticbeanstalk').and_return(on_elastic_beanstalk)

    config = Puma::Configuration.new({ config_files: [ Rails.root.join('config/puma.rb').to_s ] }, {}, ENV)
    config.clamp
  end

  context 'on Elastic Beanstalk' do
    it 'binds the Unix socket nginx proxies to even in single mode' do
      options = puma_options(env: { 'WEB_CONCURRENCY' => '0' }, on_elastic_beanstalk: true)

      expect(options[:workers]).to eq(0)
      expect(options[:binds]).to eq([ 'unix:///var/run/puma/my_app.sock' ])
    end

    it 'binds the same socket in cluster mode' do
      options = puma_options(env: { 'WEB_CONCURRENCY' => '2' }, on_elastic_beanstalk: true)

      expect(options[:workers]).to eq(2)
      expect(options[:binds]).to eq([ 'unix:///var/run/puma/my_app.sock' ])
      expect(options[:preload_app]).to be(true)
      expect(options[:worker_timeout]).to eq(120)
    end

    it 'defaults to 2 workers in production until WEB_CONCURRENCY is set' do
      options = puma_options(env: { 'RAILS_ENV' => 'production' }, on_elastic_beanstalk: true)

      expect(options[:workers]).to eq(2)
      expect(options[:environment]).to eq('production')
    end

    it 'defaults to 2 workers in staging too' do
      expect(puma_options(env: { 'RAILS_ENV' => 'staging' }, on_elastic_beanstalk: true)[:workers]).to eq(2)
    end

    it 'runs from the deployed release and logs where EB collects logs' do
      options = puma_options(on_elastic_beanstalk: true)

      expect(options[:directory]).to eq('/var/app/current')
      expect(options[:redirect_stdout]).to eq('/var/log/puma/puma.log')
    end

    it 'cycles GoodJob around the fork so each worker runs its own threads' do
      options = puma_options(env: { 'WEB_CONCURRENCY' => '2' }, on_elastic_beanstalk: true)

      expect(options[:before_fork]).to be_present
      expect(options[:before_worker_boot]).to be_present
      expect(options[:before_worker_shutdown]).to be_present
    end
  end

  context 'anywhere else' do
    it 'listens on TCP 3000 in a single process outside production and staging' do
      options = puma_options(env: { 'RAILS_ENV' => 'test' })

      expect(options[:workers]).to eq(0)
      expect(options[:binds]).to contain_exactly(a_string_matching(%r{\Atcp://.+:3000\z}))
    end

    it 'honours PORT' do
      expect(puma_options(env: { 'PORT' => '4000' })[:binds]).to contain_exactly(a_string_matching(%r{\Atcp://.+:4000\z}))
    end

    it 'still lets WEB_CONCURRENCY turn on cluster mode' do
      expect(puma_options(env: { 'WEB_CONCURRENCY' => '2' })[:workers]).to eq(2)
    end
  end
end
