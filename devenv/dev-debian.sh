#!/usr/bin/env bash

if ! [ -f ./dev-debian.compose ]; then echo "dev-debian.compose file not found"; exit 1; fi
if ! [ -f ./dev-debian.Dockerfile ]; then echo "dev-debian.Dockerfile file not found"; exit 1; fi

if command -v podman &> /dev/null
then
  podman compose -f dev-debian.compose up -d
elif command -v podman &> /dev/null
then
  docker compose -f dev-debian.compose up -d
fi