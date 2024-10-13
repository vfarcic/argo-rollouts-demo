#!/usr/bin/env nu

def install_ingress [hyperscaler: string] {

    (
        helm upgrade --install traefik traefik
            --repo https://helm.traefik.io/traefik
            --namespace traefik --create-namespace --wait
    )

    mut ingress_ip = ""

    if $hyperscaler == "aws" {

        sleep 10sec

        let ingress_hostname = (
            kubectl --namespace traefik
                get service traefik --output yaml
                | from yaml
                | get status.loadBalancer.ingress.0.hostname
        )

        while $ingress_ip == "" {
            print "Waiting for Ingress Service IP..."
            sleep 10sec
            $ingress_ip = (dig +short $ingress_hostname)
        }

    } else {

        while $ingress_ip == "" {
            print "Waiting for Ingress Service IP..."
            sleep 10sec
            $ingress_ip = (
                kubectl --namespace traefik
                    get service traefik --output yaml
                    | from yaml
                    | get status.loadBalancer.ingress.0.ip
            )
        }
    }

    $ingress_ip = $ingress_ip | lines | first

    $"export INGRESS_IP=($ingress_ip)\n" | save --append .env
    $"export INGRESS_HOST=($ingress_ip).nip.io\n" | save --append .env

    {ip: $ingress_ip, host: $"($ingress_ip).nip.io", class: "traefik"}

}
