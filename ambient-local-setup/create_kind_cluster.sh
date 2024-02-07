#!/bin/bash

kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ambient-lab
nodes:
- role: control-plane
- role: worker
- role: worker
EOF

