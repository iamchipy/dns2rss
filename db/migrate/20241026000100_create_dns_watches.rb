# frozen_string_literal: true

require "active_record"

class CreateDnsWatches < ActiveRecord::Migration[7.1]
  def change
    create_table :dns_watches do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :domain, null: false
      t.string :record_type, null: false
      t.string :record_name, null: false
      t.integer :interval_seconds, null: false, default: 300
      t.datetime :last_checked_at
      t.datetime :next_check_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.text :last_value

      t.timestamps
    end

    add_index :dns_watches, :user_id
    add_index :dns_watches, :next_check_at
    add_index :dns_watches, %i[user_id domain record_type record_name], unique: true,
                              name: "index_dns_watches_uniqueness"
  end
end
