module API
  module V1
    class RequestsController < BaseController
      before_action :set_facade

      def index
        render json: { message: 'not yet implemented' }, status: :not_implemented
      end

      def create
        find_request_params
        course_id = @course_to_lms.external_course_id.to_i
        assignment_id = @assignment.external_assignment_id.to_i

        student = User.find_by(canvas_uid: params[:student_uid].to_s)
        unless student
          render json: { error: 'Student not found' }.to_json, status: :not_found
          return
        end

        # Query the base ("Everyone") dates. get_base_dates reads the assignment
        # with override_assignment_dates=false, whose top-level dates are the
        # base dates for any number of overrides. See docs/Canvas_Dates_API.md.
        base_dates = @canvas_facade.get_base_dates(course_id, assignment_id)
        if base_dates.nil?
          render json: { error: 'Could not fetch assignment dates from Canvas' }.to_json,
                 status: :internal_server_error
          return
        end

        # Provision Extension
        begin
          override = @canvas_facade.provision_extension(
            course_id,
            params[:student_uid].to_i,
            assignment_id,
            params[:new_due_date]
          )
        rescue CanvasFacade::CanvasAPIError, FailedPipelineError, NotFoundError => e
          render json: { error: e.message }.to_json, status: :internal_server_error
          return
        end

        @request = Request.new(
          course: @course,
          assignment: @assignment,
          user: student,
          requested_due_date: override.override_due_date || params[:new_due_date],
          reason: params[:reason].presence || 'API request',
          status: 'approved',
          external_extension_id: override.id
        )
        unless @request.save
          render json: { error: "Extension provisioned, but local save failed: #{@request.errors.full_messages.join(', ')}" }.to_json,
                 status: :internal_server_error
          return
        end
        render json: @request.to_json, status: :ok
      end

      def destroy
        render json: { message: 'not yet implemented' }, status: :not_implemented
      end

      private

      def set_facade
        Rails.logger.info "Using CANVAS_URL: #{ENV.fetch('CANVAS_URL', nil)}"
        # not sure if auth key will be in the request headers or in cookie
        @canvas_facade = CanvasFacade.new(request.headers['Authorization'])
      end

      def find_request_params
        @lms = Lms.find(params[:lms_id])
        @course = Course.find(params[:course_id])
        @assignment = Assignment.find(params[:assignment_id])
        @course_to_lms = CourseToLms.find(@assignment.course_to_lms_id)
      end
    end
  end
end
