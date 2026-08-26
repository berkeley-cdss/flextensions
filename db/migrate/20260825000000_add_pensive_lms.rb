class AddPensiveLms < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO lmss (id, lms_name, lms_base_url, use_auth_token, created_at, updated_at)
        VALUES (3, 'Pensive', 'https://www.pensieve.co', FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO UPDATE SET
          lms_name = EXCLUDED.lms_name,
          lms_base_url = EXCLUDED.lms_base_url,
          use_auth_token = EXCLUDED.use_auth_token,
          updated_at = EXCLUDED.updated_at
      SQL
    end
  end

  def down
    safety_assured do
      execute "DELETE FROM lmss WHERE id = 3 AND lms_name = 'Pensive'"
    end
  end
end
