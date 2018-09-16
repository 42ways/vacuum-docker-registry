.PHONY: docker

docker:
	docker build -t vacuum-docker-registry .

test-docker: docker
	docker run -it vacuum-docker-registry rake test

