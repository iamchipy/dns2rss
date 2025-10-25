# frozen_string_literal: true

require "active_record"

ActiveRecord::Schema[7.1].define(version: 2024_10_26_000200) do
  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "feed_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["feed_token"], name: "index_users_on_feed_token", unique: true
  end

  create_table "dns_watches", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "domain", null: false
    t.string "record_type", null: false
    t.string "record_name", null: false
    t.integer "interval_seconds", default: 300, null: false
    t.datetime "last_checked_at"
    t.datetime "next_check_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "last_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_dns_watches_on_user_id"
    t.index ["next_check_at"], name: "index_dns_watches_on_next_check_at"
    t.index ["user_id", "domain", "record_type", "record_name"], name: "index_dns_watches_uniqueness", unique: true
  end

  create_table "dns_changes", force: :cascade do |t|
    t.bigint "dns_watch_id", null: false
    t.datetime "detected_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.text "from_value"
    t.text "to_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["dns_watch_id", "detected_at"], name: "index_dns_changes_on_dns_watch_id_and_detected_at"
  end

  add_foreign_key "dns_watches", "users"
  add_foreign_key "dns_changes", "dns_watches"
end
