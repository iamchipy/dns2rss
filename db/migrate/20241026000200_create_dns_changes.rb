# frozen_string_literal: true

require "active_record"

class CreateDnsChanges < ActiveRecord::Migration[7.1]
  def change
    create_table :dns_changes do |t|
      t.references :dns_watch, null: false, foreign_key: true, index: false
      t.datetime :detected_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.text :from_value
      t.text :to_value, null: false

      t.timestamps
    end

    add_index :dns_changes, %i[dns_watch_id detected_at]
  end
end
