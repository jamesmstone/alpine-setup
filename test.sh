#!/bin/sh
set -eo
shfmt(){
	docker run -it --rm -v "$(pwd)":/sh -w /sh jamesmstone/shfmt "$@"
}
shfmt -l ./
docker build -t alpine-setup .
