#!/bin/bash

set -a
. ./.env
set +a

tofu() {
	. ./source.sh
	( cd ./tofu-infra
	command tofu "$@" )
}