#!/usr/bin/env bash

CLUSTER_NAME='yggdrasil'

# == k3d ==
k3d cluster create "$CLUSTER_NAME" -p "8081:80@loadbalancer" --agents 2
