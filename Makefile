# Find documentation in README.md under
# the heading "Makefile Options".

SHELL := /bin/bash

default: compose-build

# Build
python-build: build.py
	python build.py change-secret-key

build-base:
	BUILD_ARGS_FILE=$$(cat .build.env 2>/dev/null); \
	for build_arg in $$BUILD_ARGS_FILE; do \
		BUILD_ARGS+="--build-arg $$build_arg "; \
	done; \
	docker build --tag openwisp/openwisp-base:intermedia-system \
	             --file ./build/openwisp_base/Dockerfile \
	             --target SYSTEM ./build/; \
	docker build --tag openwisp/openwisp-base:intermedia-python \
	             --file ./build/openwisp_base/Dockerfile \
	             --target PYTHON ./build/ \
	             $$BUILD_ARGS; \
	docker build --tag openwisp/openwisp-base:latest \
	             --file ./build/openwisp_base/Dockerfile ./build/ \
	             $$BUILD_ARGS

compose-build: python-build build-base
	docker-compose build --parallel
	python build.py default-secret-key

publish-build: build-base
	docker-compose build --parallel

# Test
runtests: develop-runtests
	docker-compose stop

develop-runtests: publish-build
	docker-compose up -d
	source ./tests/tests.sh && init_tests

travis-runtests: publish-build
	docker-compose up -d
	echo "127.0.0.1 dashboard.openwisp.org controller.openwisp.org" \
	     "radius.openwisp.org topology.openwisp.org" | sudo tee -a /etc/hosts
	source ./tests/tests.sh && init_tests logs

# Development
develop: publish-build
	docker-compose up -d
	docker-compose logs -f

# Clean
clean:
	docker-compose stop
	docker-compose down --remove-orphans --volumes --rmi all
	docker-compose rm -svf
	docker rmi --force openwisp/openwisp-base:latest \
				openwisp/openwisp-base:intermedia-system \
				openwisp/openwisp-base:intermedia-python \
				`docker images -f "dangling=true" -q` || true

# Publish
publish: publish-build develop-runtests
	docker push openwisp/openwisp-base:latest
	docker-compose push
