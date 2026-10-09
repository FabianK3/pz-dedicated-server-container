.PHONY: build export start stop clean clean-full

build:
	docker build -t pzserver:latest .

export: build
	docker save -o pzserver.tar pzserver:latest

start: build
	mkdir -p "./volumes/data" "./volumes/mods"
	docker run -d \
		--name pzserver \
		--network host \
		--stop-timeout 120 \
		-v "$(CURDIR)/volumes/data:/home/ubuntu/Zomboid" \
		-v "$(CURDIR)/volumes/mods:/opt/pzserver/steamapps/workshop" \
		pzserver:latest

start-compose: build
	mkdir -p "./volumes/data" "./volumes/mods"
	docker-compose up -d

stop:
	-docker stop pzserver
	-docker rm pzserver

stop-compose:
	docker-compose down
	-docker rm pzserver

clean: stop
	-rm pzserver.tar
	@if docker image inspect pzserver:latest >/dev/null 2>&1; then docker image rm pzserver:latest; fi
	docker builder prune -af

clean-full: clean
	-rm -r -- "$(CURDIR)/volumes"
