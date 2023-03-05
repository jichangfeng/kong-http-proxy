FROM kong:latest
RUN apk add --update curl
RUN mkdir -p /root/kong-http-proxy
COPY . /root/kong-http-proxy/
RUN cd /root/kong-http-proxy && luarocks make