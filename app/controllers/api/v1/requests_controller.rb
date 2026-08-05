module API
  module V1
    class RequestsController < BaseController
      before_action :validate_write_token

      def index
        render json: { message: 'not yet implemented' }, status: :not_implemented
      end

      def create
        find_request_params

        student = User.find_by(canvas_uid: params[:student_uid].to_s)
        unless student
          render json: { error: 'Student not found' }, status: :not_found
          return
        end

        @request = @course.requests.new(
          assignment: @assignment,
          user: student,
          requested_due_date: params[:new_due_date],
          reason: params[:reason]
        )

        if @request.save
          render json: @request, status: :created
        else
          render json: { error: @request.errors.full_messages.join(', ') }, status: :unprocessable_content
        end
      end

      def destroy
        render json: { message: 'not yet implemented' }, status: :not_implemented
      end

      private

      def validate_write_token
        # This endpoint is not ready for production. The check below only
        # verifies that *some* Authorization header is present, which is not
        # real authentication, so any fake token would be able to write data.
        # Until proper token validation is implemented, refuse every request
        # outside the test environment. Specs run in the test environment and
        # continue to exercise the controller's behavior.
        unless Rails.env.test?
          render json: { error: 'This endpoint is not available' }, status: :forbidden
          return
        end

        token = request.headers['Authorization']
        return if token.present?

        render json: { error: 'Missing Authorization token' }, status: :unauthorized
      end

      def find_request_params
        @lms = Lms.find(params.expect(:lms_id))
        @course = Course.find(params.expect(:course_id))
        @assignment = Assignment.find(params.expect(:assignment_id))
        @course_to_lms = CourseToLms.find(@assignment.course_to_lms_id)
      end
    end
  end
end
