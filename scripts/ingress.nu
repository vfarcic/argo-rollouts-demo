#!/usr/bin/env nu

def install_ingress [hyperscaler: string] {

    (
        helm upgrade --install traefik traefik
            --repo https://helm.traefik.io/traefik
            --namespace traefik --create-namespace --wait
    )

    mut ingress_ip = ""

    if $hyperscaler == "aws" {

    #     INGRESS_IPNAME=$(kubectl --namespace projectcontour get service contour-envoy --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")

    #     INGRESS_IP=$(dig +short $INGRESS_IPNAME) 

    #     while [ -z "$INGRESS_IP" ]; do
    #         sleep 10
    #         INGRESS_IPNAME=$(kubectl --namespace projectcontour get service contour-envoy --output jsonpath="{.status.loadBalancer.ingress[0].hostname}")
    #         INGRESS_IP=$(dig +short $INGRESS_IPNAME) 
    #     done

    } else {

        while $ingress_ip == "" {
            print "Waiting for Ingress Service IP..."
            $ingress_ip = (
                kubectl --namespace traefik
                    get service traefik --output yaml
                    | from yaml
                    | get status.loadBalancer.ingress.0.ip
            )
        }
        $ingress_ip = $ingress_ip | lines | first
    }

    $"export INGRESS_IP=($ingress_ip)\n" | save --append .env

    {ip: $ingress_ip, host: $"($ingress_ip).nip.io", class: "traefik"}

}
