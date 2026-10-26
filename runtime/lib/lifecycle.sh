#!/usr/bin/env bash

# Runtime lifecycle cleanup shared by the root launcher and entrypoints.
cleanup_runtime() {
  trap - SIGINT SIGTERM ERR EXIT
}
