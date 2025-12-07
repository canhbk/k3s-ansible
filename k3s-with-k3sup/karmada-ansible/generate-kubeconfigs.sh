#!/bin/bash

contexts=("vn2" "jp" "sg" "eu" "us")

mkdir -p ./split-configs

for context in "${contexts[@]}"; do
  output="./split-configs/config-${context}"
  echo "Exporting $context to $output"
  KUBECONFIG=~/.kube/config kubectl config view --minify --flatten --context=$context > "$output"
done
