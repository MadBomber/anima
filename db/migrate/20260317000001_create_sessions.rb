# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.string :view_mode, default: "basic", null: false
      t.boolean :processing, default: false, null: false
      t.boolean :interrupt_requested, default: false, null: false
      t.references :parent_session, foreign_key: {to_table: :sessions}, null: true
      t.text :prompt
      t.json :granted_tools
      t.string :name
      t.json :viewport_event_ids, default: [], null: false
      t.json :active_skills, default: [], null: false
      t.string :active_workflow

      t.timestamps
    end
  end
end
