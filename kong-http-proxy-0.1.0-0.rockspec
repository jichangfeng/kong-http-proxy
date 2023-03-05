package = "kong-http-proxy"
version = "0.1.0-0"
source = {
  url = "git://github.com/jichangfeng/kong-http-proxy/"
}
description = {
  summary = "A Kong plugin that allows access to an upstream url through a http proxy",
  license = "Apache 2.0"
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.http-proxy.handler"] = "src/handler.lua",
    ["kong.plugins.http-proxy.access"] = "src/access.lua",
    ["kong.plugins.http-proxy.schema"] = "src/schema.lua"
  }
}