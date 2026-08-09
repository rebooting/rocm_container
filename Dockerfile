# ROCm user-space development/runtime environment on Ubuntu 24.04.
# The amdgpu kernel driver must be installed on the host, not in this image.
FROM ubuntu:24.04

ARG ROCM_VERSION=7.2
ARG AMDGPU_INSTALL_PACKAGE=amdgpu-install_7.2.70200-1_all.deb

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/rocm/bin:/opt/rocm/llvm/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        python3-setuptools \
        python3-wheel \
        wget \
    && wget --no-verbose \
        "https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/${AMDGPU_INSTALL_PACKAGE}" \
    && apt-get install --yes "./${AMDGPU_INSTALL_PACKAGE}" \
    && apt-get update \
    && apt-get install --yes --no-install-recommends rocm \
    && rm --force "${AMDGPU_INSTALL_PACKAGE}" \
    && apt-get clean \
    && rm --recursive --force /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
