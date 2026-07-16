require 'csv'

# Renders a collection of Request records as CSV for the export endpoint.
#
# Several columns (assignment name, student name, student id) are user- or
# LMS-controlled. Spreadsheet programs treat a cell that begins with =, +, -, @,
# a tab, or a carriage return as a formula, so a value like `=HYPERLINK(...)`
# would execute when the exported file is opened. #sanitize_cell defuses that
# ("CSV injection") by prefixing any such value with a single quote, forcing the
# spreadsheet to read it as literal text.
class RequestCsvPresenter
  HEADERS = [
    'Assignment', 'Student Name', 'Student ID', 'Requested At',
    'Original Due Date', 'Requested Due Date', 'Status'
  ].freeze

  # Leading characters that make a spreadsheet interpret a cell as a formula.
  FORMULA_TRIGGERS = [ '=', '+', '-', '@', "\t", "\r" ].freeze

  def initialize(requests)
    @requests = requests
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS
      @requests.find_each { |request| csv << row_for(request) }
    end
  end

  private

  def row_for(request)
    [
      request.assignment&.name,
      request.user&.name,
      request.user&.student_id,
      request.created_at,
      request.assignment&.due_date,
      request.requested_due_date,
      request.status
    ].map { |value| sanitize_cell(value) }
  end

  def sanitize_cell(value)
    return value if value.nil?

    string = value.to_s
    return string unless FORMULA_TRIGGERS.include?(string[0])

    "'#{string}"
  end
end
