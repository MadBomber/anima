# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :session, null: false, foreign_key: true
      t.string :event_type, null: false
      t.json :payload, null: false, default: {}
      t.integer :timestamp, limit: 8, null: false
      t.integer :token_count, default: 0, null: false
      t.string :tool_use_id
      t.string :status

      t.timestamps
    end

    add_index :events, [:session_id, :event_type]
    add_index :events, :tool_use_id
    add_index :events, [:session_id, :status]
    add_index :events, [:session_id, :id], name: "index_events_on_session_id_and_id"
  end
end
