Warning: The docker images are mostly generated using GPT 5.6 Luna. ** Use at your own risk **

I've tested the setup on Fedora 44 + Framework desktop host, specifically on :
- llama-cpp's rocm binary ( the path parameters in the Makefile needs to be adjusted to whereever you download your llama-cpp rocm binaries and your models )
- comfy-ui running some models.


# ROCm containers

Docker images for running AMD GPU workloads with ROCm 7.2. The repository
provides:

- `rocm-ubuntu:7.2`: an Ubuntu 24.04 ROCm development/runtime base image.
- `comfyui-rocm:7.2`: ComfyUI with ROCm-enabled PyTorch, built on the base
  image.
- Make targets for interactive shells and a llama.cpp server.

The images contain user-space ROCm libraries only. The host must provide a
compatible AMDGPU kernel driver.

## Requirements

- Linux host with a supported AMD GPU and AMDGPU kernel driver
- Docker, or a compatible runtime such as Podman
- Access to `/dev/kfd` and `/dev/dri`
- Membership in the host's `video` group, or an equivalent numeric group ID

The run targets pass the following GPU access options to the container:

```text
--device /dev/kfd
--device /dev/dri
--security-opt seccomp=unconfined
```





## Quick start

Build the base image:

```sh
make build
```

Run an interactive ROCm shell:

```sh
make shell
```

Verify GPU access from inside the container:

```sh
rocminfo
amd-smi list
```

You can build directly with Docker as well:

```sh
docker build --tag rocm-ubuntu:7.2 .
```

## ComfyUI

Build the ComfyUI image after building the base image:

```sh
make comfyui-build
```

The build uses Python 3.12, installs PyTorch, torchvision, and torchaudio from
the ROCm 7.2 wheel index, and then installs ComfyUI's remaining requirements.
The default ComfyUI source ref is `master`; pin a tag or commit-compatible
branch for reproducible builds:

```sh
make comfyui-build COMFYUI_REF=<tag-or-branch>
```

Run ComfyUI with GPU access:

```sh
make comfyui-shell
```

Then open <http://localhost:8188>.

The target mounts `$HOME/comfyui` at `/workspace/ComfyUI`. On first start, the
entrypoint seeds missing files from the image without overwriting existing
files. This preserves the application source, models, custom nodes, settings,
inputs, and outputs between containers.

Put model files in the usual ComfyUI directories, for example:

```text
$HOME/comfyui/
├── models/
│   ├── checkpoints/
│   ├── diffusion_models/
│   ├── loras/
│   ├── text_encoders/
│   └── vae/
├── custom_nodes/
├── input/
├── output/
└── user/
```

The image runs as the host user's default UID and GID, detected by `make`.
Override them when necessary:

```sh
make comfyui-build APP_UID=1000 APP_GID=1000
```

Check that PyTorch can see the GPU:

```sh
docker run --rm \
  --device /dev/kfd \
  --device /dev/dri \
  --security-opt seccomp=unconfined \
  --group-add video \
  comfyui-rocm:7.2 \
  python -c 'import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0))'
```

## llama.cpp server

The `llama-server` target expects a llama.cpp checkout or build output at
`$HOME/Downloads/rocm-llama-cpp` and model files at `$HOME/Downloads/models`.
These host directories are controlled by `LLAMA_DIR` and `MODELS_DIR`, while
retaining your current paths as the defaults:

```text
LLAMA_DIR=$HOME/Downloads/rocm-llama-cpp
MODELS_DIR=$HOME/Downloads/models
```

Override them if your llama.cpp binary or models are stored elsewhere:

```sh
make llama-server \
  LLAMA_DIR=/path/to/rocm-llama-cpp \
  MODELS_DIR=/path/to/models
```

The same variables are used by `make shell`. Inside the containers, the
directories are mounted at `/llama` and `/models` respectively.

The default model is:

```text
/models/gemma-4-26B-A4B-it-qat-q4_0-unquantized-heretic.Q4_K_M.gguf
```

Start the server with:

```sh
make llama-server
```

Override the model path when needed:

```sh
make llama-server MODEL=/models/my-model.gguf
```

The server listens on port `8080` and is configured to use up to 99 GPU
layers.

## Make targets

| Target | Purpose |
| --- | --- |
| `make build` | Build the ROCm base image |
| `make comfyui-build` | Build the ComfyUI image |
| `make shell` | Open a GPU-enabled base-image shell |
| `make comfyui-shell` | Run ComfyUI on port `8188` |
| `make llama-server` | Run the llama.cpp server on port `8080` |
| `make remove-image` | Remove the base image |
| `make remove-comfyui-image` | Remove the ComfyUI image |
| `make prune-system` | Prune unused Docker data |
| `make help` | Show available targets |

Common variables can be overridden on the command line:

```sh
make IMAGE=my-rocm-image:tag DOCKER=podman build
make BASE_IMAGE=my-rocm-image:tag COMFYUI_IMAGE=my-comfyui:tag comfyui-build
```

Important defaults are:

```text
IMAGE=rocm-ubuntu:7.2
COMFYUI_IMAGE=comfyui-rocm:7.2
COMFYUI_REF=master
PYTORCH_INDEX_URL=https://download.pytorch.org/whl/rocm7.2
LLAMA_DIR=$HOME/Downloads/rocm-llama-cpp
MODELS_DIR=$HOME/Downloads/models
```

## Notes

- The host kernel driver is intentionally not installed in either image.
- Large ROCm and PyTorch dependencies make these images several gigabytes.
- `--ipc host` and `--cap-add SYS_PTRACE` are enabled by the ComfyUI target for
  GPU workloads and debugging compatibility.

Further host and runtime details are available in AMD's [ROCm Docker
instructions](https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.2.0/how-to/docker.html),
the [ComfyUI AMD GPU notes](https://github.com/Comfy-Org/ComfyUI#amd-gpus-linux),
and AMD's [ComfyUI ROCm guide](https://rocm.docs.amd.com/projects/comfyui/en/docs-26.04/install/comfyui-install.html).
