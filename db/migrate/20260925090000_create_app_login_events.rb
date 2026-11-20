class CreateAppLoginEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :app_login_events do |t|
      # Who logged in, captured at login time. The name and role are stored on
      # the row rather than joined later so the list still reads correctly after
      # a user is renamed, reassigned or removed.
      t.string :account_type, null: false          # "User" or "Vrp"
      t.bigint :account_id
      t.string :user_name
      t.string :display_name
      t.string :role
      t.datetime :logged_in_at, null: false

      t.timestamps
    end

    # The list is always "one day at a time", newest first.
    add_index :app_login_events, [:logged_in_at, :id], order: { logged_in_at: :desc, id: :desc },
      name: "index_app_login_events_on_logged_in_at"
    add_index :app_login_events, [:account_type, :account_id]
  end
end
