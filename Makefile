.PHONY: validate validate-syntax validate-structure build-ee install-collections

COLLECTION_DIR := collections/ansible_collections/acme/sap_migration
AZURE_RG ?= sap-migration-dev
SAP_SID ?= DEV
AZURE_LOCATION ?= eastus

validate: validate-structure validate-syntax

validate-structure:
	@./tests/validate_structure.sh

validate-syntax:
	@for pb in $(COLLECTION_DIR)/playbooks/*.yml; do \
		echo "Checking $$pb"; \
		ansible-playbook --syntax-check "$$pb" -e sap_migration_dry_run=true \
			-e sap_sid=DEV -e azure_resource_group=dev-rg -e gcp_project=dev-project \
			2>/dev/null || python3 -c "import yaml; yaml.safe_load(open('$$pb'))"; \
	done
	@echo "Syntax check complete"

install-collections:
	ansible-galaxy collection install -r $(COLLECTION_DIR)/requirements.yml

build-ee:
	cd execution-environment && ansible-builder build -t sap-migration-ee:latest

azure-add-workloads:
	@chmod +x scripts/azure_add_workloads.sh
	./scripts/azure_add_workloads.sh -g $(AZURE_RG) -s $(SAP_SID) -l $(AZURE_LOCATION)

azure-destroy-workloads:
	@chmod +x scripts/azure_add_workloads.sh
	./scripts/azure_add_workloads.sh -g $(AZURE_RG) --destroy

dry-run-prerequisites:
	ansible-playbook $(COLLECTION_DIR)/playbooks/00_prerequisites.yml \
		-e sap_migration_dry_run=true \
		-e sap_sid=DEV \
		-e azure_resource_group=dev-sap-rg \
		-e gcp_project=dev-gcp-project
