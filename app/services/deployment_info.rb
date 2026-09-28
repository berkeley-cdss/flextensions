# Resolves metadata about the currently running release: when it was built and
# which commit it is.
#
# Sources are checked in priority order so the mechanism can be swapped without
# touching application code:
#
#   1. Environment variables (DEPLOY_TIMESTAMP / GIT_COMMIT). Elastic Beanstalk
#      already exports GIT_COMMIT -- see .ebextensions/03_git_info.config. Any
#      other platform only needs to export the same two variables.
#   2. The DEPLOYED_AT / REVISION files stamped into the artifact by the build
#      (see buildspec.yml). These travel with the code, so every instance behind
#      the load balancer reports the same release -- unlike a timestamp taken on
#      the instance, which would differ after an autoscale-out or a health
#      replacement re-runs the deploy steps for unchanged code.
#   3. Local git, so the footer is still useful in development.
#
# Values are memoized because they cannot change while the process is running.
# In development the constant is reloaded (and the memo cleared) on code change.
module DeploymentInfo
  REPO_URL = 'https://github.com/berkeley-cdss/flextensions'.freeze
  SHA_PATTERN = /\A[0-9a-f]{7,40}\z/
  SHORT_SHA_LENGTH = 7
  # Rejects digit strings that are not really epoch seconds, such as a
  # `%Y%m%d%H%M%S` stamp or milliseconds. Spans 2000-01-01 to 2100-01-01.
  PLAUSIBLE_EPOCH = (946_684_800..4_102_444_800)

  class << self
    # @return [ActiveSupport::TimeWithZone, nil]
    def deployed_at
      return @deployed_at if defined?(@deployed_at)

      @deployed_at = parse_time(ENV['DEPLOY_TIMESTAMP']) || parse_time(read_stamp('DEPLOYED_AT'))
    end

    # @return [String, nil] the full commit SHA, or nil when it cannot be determined
    def commit
      return @commit if defined?(@commit)

      sha = ENV['GIT_COMMIT'].presence ||
            ENV['HEROKU_SLUG_COMMIT'].presence ||
            read_stamp('REVISION') ||
            local_git_commit
      # Deploy scripts fall back to placeholders such as "unknown". Treat
      # anything that is not a SHA as "no commit" rather than showing it off.
      @commit = (sha if sha&.match?(SHA_PATTERN))
    end

    def short_commit
      commit&.first(SHORT_SHA_LENGTH)
    end

    def commit_url
      "#{REPO_URL}/commit/#{commit}" if commit
    end

    private

    def parse_time(value)
      value = value.to_s.strip
      return nil if value.empty?

      # Accept both ISO 8601 strings and Unix epoch seconds.
      return Time.zone.parse(value) unless value.match?(/\A\d+\z/)

      seconds = value.to_i
      Time.zone.at(seconds) if PLAUSIBLE_EPOCH.cover?(seconds)
    rescue ArgumentError, RangeError, TypeError
      nil
    end

    # Reads a file stamped into the deployed artifact by the build.
    def read_stamp(filename)
      path = Rails.root.join(filename)
      File.read(path).strip.presence
    rescue SystemCallError, ArgumentError # missing/unreadable, or invalid encoding
      nil
    end

    def local_git_commit
      `git rev-parse HEAD 2>/dev/null`.strip.presence
    rescue StandardError
      nil
    end
  end
end
