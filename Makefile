# lab-hetzner-gitops-k3s — k3s + ArgoCD GitOps on Hetzner CX33
# See plan/init/01-plan.md for the full plan.
SHELL := /bin/bash
.DEFAULT_GOAL := help

HOST       := hetzner-cx33-nbg
KUBECONFIG ?= $(HOME)/.kube/hetzner-cx33-nbg.yaml
export KUBECONFIG

ANSIBLE_DIR      := ansible
KUSTOMIZE_PLUGIN := --enable-alpha-plugins --enable-exec
KUSTOMIZE_HELM   := --enable-helm

.PHONY: help bootstrap bootstrap-k3s bootstrap-argocd kubeconfig argocd-bootstrap \
        nodes apps sops-encrypt validate validate-kustomize validate-ansible

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk -F':.*?## ' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Full bootstrap: k3s + ArgoCD + KSOPS (idempotent)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

bootstrap-k3s: ## Phase 1 only: host prep + k3s
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/k3s.yml

bootstrap-argocd: ## Phase 2 only: age key + ArgoCD + KSOPS
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/argocd.yml

kubeconfig: ## Replace ~/.kube/config with the VPS kubeconfig (context hetzner-cx33-nbg)
	./scripts/get-kubeconfig.sh

argocd-bootstrap: ## Register the root app-of-apps with ArgoCD (one-time)
	kubectl apply -k cluster/bootstrap/root-app

nodes: ## Show cluster nodes
	kubectl get nodes -o wide

apps: ## Show ArgoCD applications
	kubectl get applications.argoproj.io -n argocd

sops-encrypt: ## Encrypt / re-key all *.sops.yaml files
	./scripts/sops-encrypt.sh

validate: validate-kustomize validate-ansible ## Run all local validation

validate-kustomize: ## Build every kustomization (incl. KSOPS + helm inflation)
	kustomize build cluster/bootstrap/root-app > /dev/null
	kustomize build cluster/bootstrap/children > /dev/null
	kustomize build $(KUSTOMIZE_HELM) cluster/platform > /dev/null
	kustomize build $(KUSTOMIZE_HELM) $(KUSTOMIZE_PLUGIN) cluster/infra > /dev/null
	@for d in cluster/apps/*/; do \
	  echo "  build $$d"; \
	  kustomize build $(KUSTOMIZE_HELM) $(KUSTOMIZE_PLUGIN) $$d > /dev/null || exit 1; \
	done
	@echo "kustomize build OK"

validate-ansible: ## Syntax-check the bootstrap playbooks
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check playbooks/site.yml
	@echo "ansible syntax OK"
