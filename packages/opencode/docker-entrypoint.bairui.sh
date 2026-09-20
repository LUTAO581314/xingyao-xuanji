#!/bin/sh
set -eu

# Keep the native config override available. A caller-provided
# OPENCODE_CONFIG_CONTENT takes precedence over the BAIRUI default.
if [ -z "${OPENCODE_CONFIG_CONTENT:-}" ]; then
  export OPENCODE_CONFIG_CONTENT='{"default_agent":"星杳","agent":{"星杳":{"mode":"primary","description":"BAIRUI personal assistant","color":"primary"}}}'
fi

exec /usr/local/bin/opencode "$@"
