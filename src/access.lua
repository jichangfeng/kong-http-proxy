local http = require "resty.http"
local cjson = require "cjson.safe"
local utils = require("kong.router.utils")
local sanitize_uri_postfix = utils.sanitize_uri_postfix
local strip_uri_args       = utils.strip_uri_args
local get_service_info     = utils.get_service_info
local get_upstream_uri_v0  = utils.get_upstream_uri_v0

_M = {}

function _M.execute(conf)
  -- kong.log.err("conf: ", cjson.encode(conf))
  -- kong.log.err("ngx.ctx.balancer_data: ", cjson.encode(ngx.ctx.balancer_data))
  -- kong.log.err("kong.router.get_route: ", cjson.encode(kong.router.get_route()))
  -- kong.log.err("kong.router.get_service: ", cjson.encode(kong.router.get_service()))

  local proxy_options = {
    http_proxy = "http://" .. conf.host .. ":" .. conf.port,
    https_proxy = "http://" .. conf.host .. ":" .. conf.port,
  }
  -- kong.log.err("proxy_options: ", cjson.encode(proxy_options))

  local connect_options = {
    scheme = ngx.ctx.balancer_data.scheme,
    host = ngx.ctx.balancer_data.host,
    port = ngx.ctx.balancer_data.port,
	ssl_verify = false,
	proxy_opts = proxy_options,
  }
  -- kong.log.err("connect_options: ", cjson.encode(connect_options))

  local request_params = {
    version = kong.request.get_http_version(),
    method = kong.request.get_method(),
    path = kong.request.get_raw_path(),
    query = kong.request.get_raw_query(),
    headers = kong.request.get_headers(),
    body = kong.request.get_raw_body(),
  }
  request_params.headers["remoteip"] = nil
  request_params.headers["x-forwarded-for"] = nil
  request_params.headers["host"] = ngx.ctx.balancer_data.host
  -- get upstream uri start
  local req_uri = kong.request.get_raw_path()
  local matched_path = kong.request.get_forwarded_prefix()
  local service = kong.router.get_service()
  local matched_route = kong.router.get_route()
  local service_protocol, _,  --service_type
        service_host, service_port,
        service_hostname_type, service_path = get_service_info(service)
  local request_prefix = matched_route.strip_path and matched_path or nil
  local request_postfix = request_prefix and req_uri:sub(#matched_path + 1) or req_uri:sub(2, -1)
  request_postfix = sanitize_uri_postfix(request_postfix) or ""
  local upstream_base = service_path or "/"
  local upstream_uri = get_upstream_uri_v0(matched_route, request_postfix, req_uri, upstream_base)
  -- get upstream uri end
  request_params.path = upstream_uri
  -- kong.log.err("request_params: ", cjson.encode(request_params))

  local httpc = http.new()

  httpc:set_timeouts(ngx.ctx.balancer_data.connect_timeout, ngx.ctx.balancer_data.send_timeout, ngx.ctx.balancer_data.read_timeout)

  -- httpc:set_proxy_options(proxy_options)

  local ok, err = httpc:connect(connect_options)
  if not ok then
    kong.log.err("failed to connect: ", err)
    return kong.response.exit(500, { message = err })
  end

  local res, err = httpc:request(request_params)

  if not res then
    kong.log.err("failed to request: ", err)
    return kong.response.exit(500, { message = err })
  end
  local response_info = {
    status = res.status,
    reason = res.reason,
    headers = res.headers,
	has_body = res.has_body,
  }
  -- kong.log.err("response info: ", cjson.encode(response_info))
  local body, err = res:read_body()
  -- kong.log.err("response body: ", body)

  local ok, err = httpc:set_keepalive()
  if not ok then
    kong.log.err("failed to set keepalive: ", err)
    return kong.response.exit(500, { message = err })
  end

  kong.response.exit(res.status, body, res.headers)
end

return _M