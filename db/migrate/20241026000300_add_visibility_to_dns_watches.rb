# frozen_string_literal: true

class AddVisibilityToDnsWatches < ActiveRecord::Migration[7.1]
  def change
    add_column :dns_watches, :visibility, :string, null: false, default: "public"
    add_index :dns_watches, :visibility
  end
end
