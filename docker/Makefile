.PHONY: prepare docker

prepare:
	mkdir -p work
	rsync -rtv --delete --exclude '*.swp' --exclude .git --exclude dev-registry .. work/


docker: prepare
	docker build -t vacuum-docker-registry .
