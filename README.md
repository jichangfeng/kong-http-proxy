# kong-http-proxy

A Kong plugin that allows access to an upstream url through a http proxy.

![---](kong-http-proxy.png?raw=true)

## Configuration
Add this plugin globally or attached to an API.
All calls to the API's upstream URL will then be proxied through the specify proxy host and port.

```bash
$ curl -X POST http://kong:8001/apis/{api}/plugins \
    --data "name=http-proxy" \
    --data "config.host=127.0.0.1" \
    --data "config.port=8118"
```

## Installation

Clone the repository, navigate to the root folder and run:
```
make install
```

Add the custom plugin’s name to the plugins list in your Kong configuration (on each Kong node):
```yaml
plugins = bundled,http-proxy
```

Restart Kong to apply the plugin:
```
kong restart
```

Or, if you want to apply a plugin without stopping Kong, you can use this:
```
kong prepare
kong reload
```
