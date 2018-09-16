# Docker ruby/rails base image; based on Ubuntu 16 with bundled ruby (2.3.1)

FROM ubuntu:18.04

# note: java 8 installed for use a jenkins builder
RUN apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y curl git ca-certificates openjdk-8-jdk-headless locales ruby ruby-dev build-essential netcat-openbsd tzdata \
        && rm -rf /var/lib/apt/lists/*

RUN useradd -m user
USER user
COPY * /home/user/
WORKDIR /home/user
CMD ./vacuum-registry.rb
