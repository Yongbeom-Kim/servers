.PHONY: help ssh_root ssh_server rsync _rsync_with_env rsync_watch rsync_ssh start stop start_detached start_remote start_remote_attached stop_remote _remote_exec_with_env_impl

SERVER_USER = server
DIR ?= /home/$(SERVER_USER)
SCP_DIR = /home/$(SERVER_USER)/setup

REMOTE_HOSTNAME=yongbeom-hetzner-auction-ubuntu-2404

SOURCE_ENV = . ./source.sh

##@ Utility
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ SSH
ssh_root: ## SSH as 'root' user
	ssh root@$${IPV4_ADDRESS}

ssh_server: ## SSH as 'server' user
	$(SOURCE_ENV) && ssh -ttt $(SERVER_USER)@$${IPV4_ADDRESS} 'cd $(DIR) && exec $$SHELL'

##@ SCP
rsync: ## Sync this directory to server
	$(SOURCE_ENV) && rsync -az --delete --progress --exclude '.git' --exclude '.env' --exclude 'tofu-infra' . $(SERVER_USER)@$${IPV4_ADDRESS}:$(SCP_DIR)

##@ Deployment
ifeq "$(DETACHED)" "1"
COMPOSE_DETACHED_FLAG = -d
SSH_TTY_FLAG = -T
else
COMPOSE_DETACHED_FLAG =
SSH_TTY_FLAG = -ttt
endif

_remote_exec_with_env_impl:
	$(SOURCE_ENV) && ssh $(SSH_TTY_FLAG) $(SERVER_USER)@$${IPV4_ADDRESS} ' \
		cd "$(SCP_DIR)" && \
		set -a && . /dev/stdin && set +a && \
		$(CMD) \
	' < .env

start_detached: ## Start services detached (only run this on the server!!!)
	DETACHED=1 $(MAKE) start

remote_start: ## Start services on remote server (detached)
	$(MAKE) rsync
	DETACHED=1 CMD="docker compose up -d --build" $(MAKE) _remote_exec_with_env_impl

remote_stop: ## Stop services on remote server
	$(MAKE) rsync
	DETACHED=0 CMD="docker compose down" $(MAKE) _remote_exec_with_env_impl

remote_logs: ## Show logs from all services on remote server
	DETACHED=0 CMD="docker compose logs -f" $(MAKE) _remote_exec_with_env_impl