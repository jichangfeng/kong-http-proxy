local typedefs = require "kong.db.schema.typedefs"

return {
  name = "http-proxy",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { host = { type = "string", required = true }, },
          { port = { type = "number", required = true }, },
          { ssl_client_cert = { type = "string", required = false, default = nil }, },
          { ssl_client_priv_key = { type = "string", required = false, default = nil }, },
          { log_enable = { type = "boolean", required = true, default = false }, },
    }, }, },
  },
}