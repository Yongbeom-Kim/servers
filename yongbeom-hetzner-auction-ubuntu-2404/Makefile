IVP4_ADDRESS = 94.130.201.117
IPV6_ADDRESS = 2a01:4f8:13b:22cb:0000:0000:0000:0000

SOURCE_ENV = set -a && . ./.env && set +a
SERVER_USER = server
DIR ?= /home/$(SERVER_USER)
SCP_DIR = /home/$(SERVER_USER)/setup

##@ Utility
help:  ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ SSH
ssh_root: ## SSH as 'root' user
	$(SOURCE_ENV) && ssh root@$(IVP4_ADDRESS)

ssh_server: ## SSH as 'server' user
	$(SOURCE_ENV) && ssh -ttt $(SERVER_USER)@$(IVP4_ADDRESS) 'cd $(DIR) && exec $$SHELL'

##@ SCP
rsync:
	@$(SOURCE_ENV) && rsync -az --delete --exclude '.git' . $(SERVER_USER)@$(IVP4_ADDRESS):$(SCP_DIR)

rsync_watch:
	@inotifywait -mrq -e modify,create,delete,move . | \
	while read; do \
		$(MAKE) rsync; \
	done

rsync_ssh:
	$(MAKE) rsync
	DIR=$(SCP_DIR) $(MAKE) ssh_server