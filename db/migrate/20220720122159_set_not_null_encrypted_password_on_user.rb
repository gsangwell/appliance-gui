class SetNotNullEncryptedPasswordOnUser < ActiveRecord::Migration[7.0]
  def change
    change_column :users, :encrypted_password, :string, limit: 128, null: true
  end
end
