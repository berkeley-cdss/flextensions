require 'rails_helper'

# Both LMS override POROs must answer the shared BaseOverride#student_ids
# contract with an array, so callers can treat overrides uniformly regardless
# of LMS (Canvas targets a list of students, Gradescope a single student).
RSpec.describe Lmss::BaseOverride do
  it 'Canvas::Override exposes the targeted students as an array' do
    override = Lmss::Canvas::Override.new(
      OpenStruct.new(id: 1, title: '1 day extension', student_ids: [ 42, 43 ],
                     unlock_at: nil, due_at: nil, lock_at: nil)
    )
    expect(override.student_ids).to eq([ 42, 43 ])
  end

  it 'Gradescope::Override wraps its single student in an array' do
    override = Lmss::Gradescope::Override.new(
      'deletePath' => '/courses/1/assignments/2/extensions/99',
      'override' => { 'user_id' => 42, 'settings' => {} }
    )
    expect(override.student_id).to eq(42)
    expect(override.student_ids).to eq([ 42 ])
  end
end
