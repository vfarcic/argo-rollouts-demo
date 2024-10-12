#!/usr/bin/env nu

source scripts/kubernetes.nu

for path in [
    "kustomize/overlays/simple/kustomization.yaml",
    "kustomize/overlays/istio/kustomization.yaml",
    "kustomize/overlays/istio-prometheus/kustomization.yaml"
] {
    open $path | reject images | save $path --force
}

destroy_kubernetes $env.HYPERSCALER
