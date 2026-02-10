REGISTRY := ghcr.io
REPO := murror
IMAGE := murror-migration-base
PRISMA_VERSION := 6.10.1
PLATFORM := linux/amd64

.PHONY: build push build-push

build:
	docker buildx build --platform $(PLATFORM) -t $(REGISTRY)/$(REPO)/$(IMAGE):$(PRISMA_VERSION) --load .

push:
	docker push $(REGISTRY)/$(REPO)/$(IMAGE):$(PRISMA_VERSION)

build-push:
	docker buildx build --platform $(PLATFORM) -t $(REGISTRY)/$(REPO)/$(IMAGE):$(PRISMA_VERSION) --push .
