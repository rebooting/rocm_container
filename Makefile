DOCKER ?= docker
IMAGE ?= rocm-ubuntu:7.2
BASE_IMAGE ?= $(IMAGE)
COMFYUI_IMAGE ?= comfyui-rocm:7.2
COMFYUI_DOCKERFILE ?= Dockerfile.comfyui
COMFYUI_REF ?= master
PYTORCH_INDEX_URL ?= https://download.pytorch.org/whl/rocm7.2
APP_UID ?= $(shell id -u)
APP_GID ?= $(shell id -g)
LLAMA_DIR ?= $(HOME)/Downloads/rocm-llama-cpp
MODELS_DIR ?= $(HOME)/Downloads/models

.PHONY: all build comfyui-build shell comfyui-shell llama-server remove-image remove-comfyui-image remove prune-system prune help

all: build

build:
	$(DOCKER) build --tag $(IMAGE) .

comfyui-build:
	$(DOCKER) build \
		--file $(COMFYUI_DOCKERFILE) \
		--build-arg BASE_IMAGE=$(BASE_IMAGE) \
		--build-arg COMFYUI_REF=$(COMFYUI_REF) \
		--build-arg PYTORCH_INDEX_URL=$(PYTORCH_INDEX_URL) \
		--build-arg APP_UID=$(APP_UID) \
		--build-arg APP_GID=$(APP_GID) \
		--tag $(COMFYUI_IMAGE) .

shell:
	$(DOCKER) run --rm -it \
		--publish 8080:8080 \
		--device /dev/kfd \
		--device /dev/dri \
		--security-opt seccomp=unconfined \
		--group-add video \
		--volume "$(LLAMA_DIR):/llama:Z" \
		--volume "$(MODELS_DIR):/models:Z" \
		$(IMAGE) bash

comfyui-shell:
	@for directory in \
		checkpoints \
		clip \
		clip_vision \
		configs \
		controlnet \
		diffusion_models \
		embeddings \
		loras \
		text_encoders \
		unet \
		upscale_models \
		vae; do \
		mkdir -p "$${HOME}/comfyui/models/$${directory}"; \
	done
	$(DOCKER) run --rm -it \
		--publish 8188:8188 \
		--device /dev/kfd \
		--device /dev/dri \
		--security-opt seccomp=unconfined \
		--cap-add SYS_PTRACE \
		--ipc host \
		--group-add video \
		--volume "$${HOME}/comfyui:/workspace/ComfyUI:Z" \
		$(COMFYUI_IMAGE)

MODEL ?= /models/gemma-4-26B-A4B-it-qat-q4_0-unquantized-heretic.Q4_K_M.gguf

define RUN_LLAMA_SERVER
	$(DOCKER) run --rm -it \
		--publish 8080:8080 \
		--device /dev/kfd \
		--device /dev/dri \
		--security-opt seccomp=unconfined \
		--group-add video \
		--volume "$(LLAMA_DIR):/llama:Z" \
		--volume "$(MODELS_DIR):/models:Z" \
		$(IMAGE) /llama/llama-server \
			--host 0.0.0.0 \
			--n-gpu-layers 99 \
			--reasoning off \
			--chat-template-kwargs '{"enable_thinking":false}' \
			-m $(MODEL)
endef

llama-server:
	$(RUN_LLAMA_SERVER)

remove-image:
	$(DOCKER) image rm $(IMAGE)

remove-comfyui-image:
	$(DOCKER) image rm $(COMFYUI_IMAGE)

remove: remove-image

prune-system:
	$(DOCKER) system prune --force

prune: prune-system

help:
	@echo "Available targets:"
	@echo "  build         Build the container image ($(IMAGE))"
	@echo "  comfyui-build Build the ComfyUI ROCm image ($(COMFYUI_IMAGE))"
	@echo "  shell         Open a shell with llama.cpp mounted at /llama"
	@echo "  comfyui-shell Run ComfyUI with AMD GPU access on port 8188"
	@echo "  llama-server  Run the llama.cpp server"
	@echo "  remove-image  Remove the container image ($(IMAGE))"
	@echo "  remove-comfyui-image  Remove the ComfyUI image ($(COMFYUI_IMAGE))"
	@echo "  prune-system  Prune unused Docker data"
	@echo ""
	@echo "Override defaults with: make IMAGE=my-image:tag DOCKER=podman build"
