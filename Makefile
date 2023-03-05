DEV_ROCKS = busted luacheck

.PHONY: install dev clean doc lint test coverage

install:
	luarocks make kong-http-proxy-*.rockspec \

dev: install
	@for rock in $(DEV_ROCKS) ; do \
		if ! command -v $$rock > /dev/null ; then \
			echo $$rock not found, installing via luarocks... ; \
			luarocks install $$rock ; \
		else \
			echo $$rock already installed, skipping ; \
		fi \
	done;

lint:
	@luacheck -q src \
		--std 'busted' \
		--globals 'require' \
		--globals 'ngx' \
		--no-redefined \
		--no-unused-args

test:
	@busted -v spec
