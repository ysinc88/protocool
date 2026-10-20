# Active Record encryption (protects the stored Gmail App Password). Keys come from
# credentials if present, otherwise from storage/encryption.json, generated on first boot.
# storage/ is git-ignored and holds the database too: back them up together.
unless Rails.application.credentials.active_record_encryption.present?
  path = Rails.root.join("storage", "encryption.json")
  unless path.exist?
    path.write(JSON.pretty_generate(%w[primary_key deterministic_key key_derivation_salt].to_h { [ it, SecureRandom.alphanumeric(32) ] }))
    File.chmod(0o600, path)
  end
  keys = JSON.parse(path.read)
  Rails.application.config.active_record.encryption.primary_key = keys["primary_key"]
  Rails.application.config.active_record.encryption.deterministic_key = keys["deterministic_key"]
  Rails.application.config.active_record.encryption.key_derivation_salt = keys["key_derivation_salt"]
end
