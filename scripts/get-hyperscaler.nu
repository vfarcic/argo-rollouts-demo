#!/usr/bin/env nu

def get-hyperscaler [] {
    let hyperscaler = [google aws azure]
        | input list $"(ansi green_bold)Which Hyperscaler do you want to use?(ansi yellow_bold)"

    $"export HYPERSCALER=($hyperscaler)\n" | save --append .env

    $hyperscaler
}
