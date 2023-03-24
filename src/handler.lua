local access = require "kong.plugins.http-proxy.access"

local HTTPProxyHandler = {
  VERSION  = "0.1.0-1",
  PRIORITY = 10,
}

function HTTPProxyHandler:access(conf)
  access.execute(conf)
end

return HTTPProxyHandler