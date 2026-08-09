#!/bin/sh
set -eu

# The bind-mounted application directory starts empty on a first run. Seed it
# from the immutable image without overwriting user-managed data or source.
cp --recursive --no-clobber --preserve=mode,timestamps \
    /opt/ComfyUI/. /workspace/ComfyUI/

exec "$@"
