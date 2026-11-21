require "rack/deflater"

# Compress textual pages, API responses and assets before the static-file
# middleware. Rack preserves already encoded/no-transform responses. Binary
# exports and partial/range responses retain their existing representation.
Rails.application.config.middleware.insert_after Rack::Sendfile, Rack::Deflater,
  include: %w[text/html application/json text/css text/javascript application/javascript image/svg+xml],
  if: ->(env, status, _headers, _body) { env["REQUEST_METHOD"] != "HEAD" && status != 206 && !env.key?("HTTP_RANGE") }
