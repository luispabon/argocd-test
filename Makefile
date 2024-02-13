# These will only work on linux & mac, amd64 or arm64, refactor if more needed
ifndef PLATFORM_PREFIX
	PLATFORM_PREFIX:=$(shell [ "`uname -s`" = "Linux" ] && echo linux || echo darwin)
endif

ifndef CPU_ARCH
	CPU_ARCH:=$(shell [ "`uname -m`" = "x86_64" ] && echo amd64 || echo arm64)
endif

### Versions
KUBE_VERSION?=v1.27.5
MK_VERSION?=v1.31.2
HELM_VERSION=v3.12.3

# See https://github.com/helmfile/helmfile/releases
# Do not add the `v` to the version, eg 0.151.0 and not v0.151.0
HELMFILE_VERSION=0.161.0
### End of versions

### Minikube options
MK_CLUSTER_NAME=argo-test
MK=$(MK_BIN) -p $(MK_CLUSTER_NAME)
KUBE_NODES?=1

# These are per node
MK_CPUS?=3
MK_MEMORY?=4g

### Binaries
BIN_FOLDER?=bin
KUBECTL?=$(MK) kubectl --
MK_BIN?=$(BIN_FOLDER)/minikube
HELM?=$(BIN_FOLDER)/helm
HELMFILE_BIN?=$(BIN_FOLDER)/helmfile
HELMFILE?=$(HELMFILE_BIN) --helm-binary=$(HELM)
### End of binaries

### Miscellaneous
POD_SHELL_IMAGE?=docker.io/luispabon/kube-shell-diagnoster:3.0.8
POD_SHELL_SERVICE_ACCOUNT?=default
### End of miscellaneous

##########################################################
#              Minikube and localdev set up              #
#         NOT TO BE RUN ON AN ACTUAL ENVIRONMENT         #
##########################################################

init: bin-install clean start enable-addons

clean:
	$(MK) delete --all --purge

start:
	$(MK) start \
		--nodes=$(KUBE_NODES) \
		--cpus=$(MK_CPUS) \
		--memory=$(MK_MEMORY) \
		--driver=kvm2

enable-addons:
	$(MK) addons enable metrics-server

stop:
	$(MK) stop

pause:
	$(MK) pause

unpause:
	$(MK) unpause

restart: stop start

ip:
	$(MK) ip

pod-shell:
	$(KUBECTL) run \
		--rm \
		-it \
		--restart=Never \
		--labels="sidecar.istio.io/inject=false" \
		--overrides='{ "spec": { "serviceAccountName": "$(POD_SHELL_SERVICE_ACCOUNT)" }}' \
		shell --image $(POD_SHELL_IMAGE)

minikube-ssh:
	$(MK) ssh

minikube-docker-root-shell:
	docker exec -it $(MK_CLUSTER_NAME) bash

dashboard:
	$(MK) dashboard

argo-install:
	helm upgrade --install argo-cd argo/argo-cd --version 5.55.0

argo-password:
	@echo "## Username: admin"
	@echo "## Password: $(shell $(KUBECTL) get secret argocd-initial-admin-secret -ojson | jq -r .data.password | base64 -d)"

argo-tunnel:
	@echo "Open https://localhost:8080"
	$(KUBECTL) port-forward service/argo-cd-argocd-server -n default 8080:443
#########################################################
#                    Binary installs                    #
#########################################################
bin-install: helm-install helmfile-install minikube-install


helm-install:
	@if [ ! -f "$(HELM)" ] || [ "`$(HELM) version --template='{{.Version}}'`" != "$(HELM_VERSION)"  ] ; then \
		echo -n "\n # Helm not found, installing for OS type $(PLATFORM_PREFIX)-$(CPU_ARCH)... "; \
		tmp_file=$(shell mktemp); \
		curl -sL "https://get.helm.sh/helm-$(HELM_VERSION)-$(PLATFORM_PREFIX)-$(CPU_ARCH).tar.gz" -o "$${tmp_file}"; \
		tar -xvzf "$${tmp_file}" --directory $(BIN_FOLDER) --strip-components 1 "$(PLATFORM_PREFIX)-$(CPU_ARCH)/helm" > /dev/null ; \
		chmod +x $(HELM); \
		rm "$${tmp_file}"; \
		echo "`$(HELM) version --short` done 👍"; \
	else echo "\n # Helm `$(HELM) version --short` already installed ✅"; \
	fi

helmfile-install:
	@if [ ! -f "$(HELMFILE_BIN)" ] || [ "`$(HELMFILE_BIN) version -o short`" != "$(HELMFILE_VERSION)" ] ; then \
		echo -n "\n # Helmfile not found, installing for OS type $(PLATFORM_PREFIX)-$(CPU_ARCH)... "; \
		tmp_file=$(shell mktemp); \
		curl -sL "https://github.com/helmfile/helmfile/releases/download/v$(HELMFILE_VERSION)/helmfile_$(HELMFILE_VERSION)_$(PLATFORM_PREFIX)_$(CPU_ARCH).tar.gz" -o "$${tmp_file}"; \
		tar -xvzf "$${tmp_file}" --directory $(BIN_FOLDER) helmfile > /dev/null ; \
		chmod +x $(HELMFILE_BIN); \
		rm "$${tmp_file}"; \
		echo "`$(HELMFILE_BIN) version -o short` done 👍"; \
	else echo "\n # Helmfile `$(HELMFILE_BIN) version -o short` already installed ✅"; \
	fi

minikube-install:
	@if [ ! -f "$(MK_BIN)" ] || [ "`$(MK_BIN) version --short`" != "$(MK_VERSION)" ]; then \
		echo -n "\n # Minikube not found, installing for OS type $(PLATFORM_PREFIX)-$(CPU_ARCH)... "; \
		curl -sL "https://github.com/kubernetes/minikube/releases/download/$(MK_VERSION)/minikube-$(PLATFORM_PREFIX)-$(CPU_ARCH)" -o "$(MK_BIN)"; \
		chmod +x $(MK_BIN); \
		echo "`$(MK_BIN) version --short` done 👍"; \
	else echo "\n # Minikube `$(MK_BIN) version --short` already installed ✅"; \
	fi
