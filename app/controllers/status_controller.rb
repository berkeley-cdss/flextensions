
class StatusController < ApplicationController
  skip_before_action :authenticated!

  def health_check
    database_status = check_database
    http_status = database_status[:database] ? :ok : :internal_server_error
    render json: { status: http_status, **database_status }, status: http_status
  end

  def version
    render json: {
      git_commit: DeploymentInfo.commit,
      deployed_at: DeploymentInfo.deployed_at,
      puma_start_time: fetch_puma_start_time,
      server_time: Time.zone.now
    }
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { database: true }
  rescue => e
    { database: false, error: e.message }
  end

  def fetch_puma_start_time
    restart_file = Rails.root.join('tmp/restart.txt')
    if File.exist?(restart_file)
      File.mtime(restart_file)
    else
      nil
    end
  end
end
