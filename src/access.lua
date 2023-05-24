local http = require "resty.http"
local cjson = require "cjson.safe"
local tools_utils = require "kong.tools.utils"
local utils = require("kong.router.utils")
local sanitize_uri_postfix = utils.sanitize_uri_postfix
local strip_uri_args       = utils.strip_uri_args
local get_service_info     = utils.get_service_info
local get_upstream_uri_v0  = utils.get_upstream_uri_v0

_M = {}

function _M.execute(conf)
  if conf.log_enable then
    kong.log("ngx.ctx.balancer_data: ", cjson.encode(ngx.ctx.balancer_data))
    kong.log("kong.router.get_route: ", cjson.encode(kong.router.get_route()))
    kong.log("kong.router.get_service: ", cjson.encode(kong.router.get_service()))
  end

  local proxy_options = {
    http_proxy = "http://" .. conf.host .. ":" .. conf.port,
    https_proxy = "http://" .. conf.host .. ":" .. conf.port,
  }
  local connect_options = {
    scheme = ngx.ctx.balancer_data.scheme,
    host = ngx.ctx.balancer_data.host,
    port = ngx.ctx.balancer_data.port,
    ssl_server_name = ngx.ctx.balancer_data.host,
    proxy_opts = proxy_options,
  }
  if conf.ssl_client_cert and conf.ssl_client_priv_key then
    connect_options.ssl_verify = true
    connect_options.ssl_client_cert = conf.ssl_client_cert
    connect_options.ssl_client_priv_key = conf.ssl_client_priv_key
  else
    connect_options.ssl_verify = false
  end
  if conf.log_enable then
    kong.log("connect_options: ", cjson.encode(connect_options))
  end

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
  if conf.log_enable then
    kong.log("request_params: ", cjson.encode(request_params))
  end

  local max_retries = ngx.ctx.balancer_data.retries
  local success = false
  local errinfo = ""
  local retries = 0
  local res_status, res_body, res_headers
  while not success and retries < max_retries do
    local httpc = http.new()
    httpc:set_timeouts(ngx.ctx.balancer_data.connect_timeout, ngx.ctx.balancer_data.send_timeout, ngx.ctx.balancer_data.read_timeout)
    -- httpc:set_proxy_options(proxy_options)
    while true do
      local ok, err = httpc:connect(connect_options)
      if not ok then
        retries = retries + 1
        errinfo = "retries: " .. retries .. ", failed to connect: " .. err
        kong.log.err(errinfo)
        break
      end
      local res, err = httpc:request(request_params)
      if not res then
        retries = retries + 1
        errinfo = "retries: " .. retries .. ", failed to request: " .. err
        kong.log.err(errinfo)
        break
      end
      local response_info = {
        status = res.status,
        reason = res.reason,
        headers = res.headers,
        has_body = res.has_body,
      }
      if conf.log_enable then
        kong.log("response info: ", cjson.encode(response_info))
      end
      local body, err = res:read_body()
      if conf.log_enable then
        if res.headers["Content-Encoding"] == "gzip" then
          kong.log("response body: ", assert(tools_utils.inflate_gzip(body)))
        else
          kong.log("response body: ", body)
        end
      end
      res_status = res.status
      res_body = body
      res_headers = res.headers
      success = true
      break
    end
    httpc:set_keepalive()
  end

  if not success then
    -- operation failed after maximum retries
    return kong.response.exit(500, { message = errinfo })
  end

  res_headers["Transfer-Encoding"] = nil
  res_headers["transfer-encoding"] = nil
  kong.response.exit(res_status, res_body, res_headers)
end

return _M