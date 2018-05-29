.PHONY: docker

docker:
	$(MAKE) -C docker

test-docker: docker
	docker run -it vacuum-docker-registry rake test

