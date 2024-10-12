#!/usr/bin/env nu

rm --force .env

source scripts/get-hyperscaler.nu
source scripts/kubernetes.nu
source scripts/ingress.nu

let hyperscaler = get-hyperscaler

create_kubernetes $hyperscaler 2 4

let ingress_data = install_ingress $hyperscaler

(
    helm upgrade --install argo-rollouts argo-rollouts
        --repo https://argoproj.github.io/argo-helm
        --namespace argo-rollouts --create-namespace --wait
)

kubectl create namespace a-team

kubectl label namespace a-team istio-injection=enabled --overwrite

(
    helm upgrade --install istio-base base
        --repo https://istio-release.storage.googleapis.com/charts
        --namespace istio-system --create-namespace --wait
)

(
    helm upgrade --install istiod istiod
        --repo https://istio-release.storage.googleapis.com/charts
        --namespace istio-system --wait
)

(
    helm upgrade --install istio-ingress gateway
        --repo https://istio-release.storage.googleapis.com/charts
        --namespace istio-system
)

mut istio_ip = ""

if $hyperscaler == "aws" {

    let istio_hostname = (
        kubectl --namespace istio-system
            get service istio-ingress --output yaml
            | from yaml
            | get status.loadBalancer.ingress.0.hostname
    )

    while $istio_ip == "" {
        print "Waiting for Ingress Service IP..."
        sleep 10sec
        $istio_ip = (dig +short $istio_hostname)
    }

} else {

    while $istio_ip == "" {
        print "Waiting for Ingress Service IP..."
        $istio_ip = (
            kubectl --namespace istio-system
                get service istio-ingress --output yaml
                | from yaml
                | get status.loadBalancer.ingress.0.ip
        )
    }
    $istio_ip = $istio_ip | lines | first
}
$"export ISTIO_IP=($istio_ip)\n" | save --append .env

let istio_host = $"($istio_ip).nip.io"
$"export ISTIO_HOST=($istio_host)\n" | save --append .env

for path in [
    "kustomize/overlays/istio/virtualservice-01.yaml",
    "kustomize/overlays/istio/virtualservice-02.yaml",
    "kustomize/overlays/istio-prometheus/virtualservice-01.yaml",
    "kustomize/overlays/istio-prometheus/virtualservice-02.yaml"
] {
    open $path
        | upsert spec.hosts.0 $"silly-demo.($istio_host)"
        | save $path --force
}

open values-prometheus.yaml
    | upsert grafana.ingress.ingressClassName $ingress_data.class
    | upsert grafana.ingress.hosts.0 $"grafana.($ingress_data.host)"
    | upsert prometheus.ingress.ingressClassName $ingress_data.class
    | upsert prometheus.ingress.hosts.0 $"prometheus.($ingress_data.host)"
    | save values-prometheus.yaml --force

(
    helm upgrade --install
        kube-prometheus-stack kube-prometheus-stack
        --repo https://prometheus-community.github.io/helm-charts
        --values values-prometheus.yaml
        --namespace monitoring --create-namespace --wait
)
