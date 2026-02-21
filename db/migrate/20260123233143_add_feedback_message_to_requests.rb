class AddFeedbackMessageToRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :requests, :feedback_message, :text
  end
end
