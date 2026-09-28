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
class Lms < ApplicationRecord
  # Relationship with Course (and CourseToLms)
  has_many :course_to_lmss
  has_many :courses, through: :course_to_lmss

  # Relationship with Assignment
  has_many :assignments

  # Relationship with LmsCredential
  has_many :lms_credentials, dependent: :destroy

  # Singleton instances for each LMS. The Canvas LMS (id 1) is guaranteed to
  # exist: it is asserted (and created if missing) once at boot by
  # config/initializers/lms_integrations.rb via `Lms.preload!`, then served
  # from memory so requests never query the lms table for it.
  def self.CANVAS_LMS
    @canvas_lms ||= preload!
  end

  def self.GRADESCOPE_LMS
    @gradescope_lms ||= find_by(id: GRADESCOPE_LMS_ID) || find_or_create_by!(
      id: GRADESCOPE_LMS_ID,
      lms_name: 'Gradescope'
    ) do |lms|
      lms.lms_base_url = 'https://www.gradescope.com'
      lms.use_auth_token = false
    end
  end

  # Asserts that the Canvas LMS row exists (creating it if necessary) and
  # caches the table's rows in memory. Called once at boot, not per request.
  def self.preload!
    @gradescope_lms = find_by(id: GRADESCOPE_LMS_ID) if @gradescope_lms.nil?
    @canvas_lms = find_or_create_by!(id: CANVAS_LMS_ID) do |lms|
      lms.lms_name = 'Canvas'
      lms.lms_base_url = ENV.fetch('CANVAS_URL', '')
      lms.use_auth_token = true
    end
  end

  # Map a linked LMS to the appropriate API facade which can be used to post extension requests
  # This requires us to map db ids to each facade in app/facades
  # You should be able to call item.course_to_lms.lms_id to get the LMS ID
  def self.facade_class(id)
    case id
    when CANVAS_LMS_ID
      CanvasFacade
    when GRADESCOPE_LMS_ID
      GradescopeFacade
    else
      raise "Unsupported LMS ID: #{id}"
    end
  end
end
