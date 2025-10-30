# frozen_string_literal: true

require "active_record"

class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :feed_token, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :feed_token, unique: true
  end
end
