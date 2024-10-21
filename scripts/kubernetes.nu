#!/usr/bin/env nu

def --env create_kubernetes [hyperscaler: string, min_nodes: int, max_nodes: int] {

    rm --force kubeconfig.yaml

    $env.KUBECONFIG = $"($env.PWD)/kubeconfig.yaml"
    $"export KUBECONFIG=($env.KUBECONFIG)\n" | save --append .env

    if $hyperscaler == "google" {

        let project_id = $"dot-(date now | format date "%Y%m%d%H%M%S")"
        $"export PROJECT_ID=($project_id)\n" | save --append .env

        gcloud projects create $project_id

        start $"https://console.cloud.google.com/marketplace/product/google/container.googleapis.com?project=($project_id)"

        print $"(ansi yellow_bold)
ENABLE(ansi reset) the API.
Press any key to continue.
"
        input

        (
            gcloud container clusters create dot --project $project_id
                --zone us-east1-b --machine-type e2-standard-8
                --enable-autoscaling --num-nodes $min_nodes
                --min-nodes $min_nodes --max-nodes $max_nodes
                --enable-network-policy --no-enable-autoupgrade
        )

        (
            gcloud container clusters get-credentials dot
                --project $project_id --zone us-east1-b
        )

    } else if $hyperscaler == "aws" {

        mut aws_access_key_id = ""
        if AWS_ACCESS_KEY_ID in $env {
            $aws_access_key_id = $env.AWS_ACCESS_KEY_ID
        } else {
            $aws_access_key_id = input $"(ansi green_bold)Enter AWS Access Key ID: (ansi reset)"
        }
        $"export AWS_ACCESS_KEY_ID=($aws_access_key_id)\n"
            | save --append .env

        mut aws_secret_access_key = ""
        if AWS_SECRET_ACCESS_KEY in $env {
            $aws_secret_access_key = $env.AWS_SECRET_ACCESS_KEY
        } else {
            $aws_secret_access_key = input $"(ansi green_bold)Enter AWS Secret Access Key: (ansi reset)" --suppress-output
        }
        $"export AWS_SECRET_ACCESS_KEY=($aws_secret_access_key)\n"
            | save --append .env
    
        mut aws_account_id = ""
        if AWS_ACCOUNT_ID in $env {
            $aws_account_id = $env.AWS_ACCOUNT_ID
        } else {
            $aws_account_id = input $"(ansi green_bold)Enter AWS Account ID: (ansi reset)"
        }
        $"export AWS_ACCOUNT_ID=($aws_account_id)\n"
            | save --append .env
    
        $"[default]
aws_access_key_id = ($aws_access_key_id)
aws_secret_access_key = ($aws_secret_access_key)
" | save aws-creds.conf --force
    
        (
            eksctl create cluster
                --config-file eksctl-config.yaml
                --kubeconfig $env.KUBECONFIG
        )
    
        (
            eksctl create addon --name aws-ebs-csi-driver
                --cluster dot-production
                --service-account-role-arn $"arn:aws:iam::($aws_account_id):role/AmazonEKS_EBS_CSI_DriverRole"
                --region us-east-1 --force
        )

    } else if $hyperscaler == "azure" {

        mut tenant_id = ""
        if AZURE_TENANT in $env {
            $tenant_id = $env.AZURE_TENANT
        } else {
            $tenant_id = input $"(ansi green_bold)Enter Azure Tenant ID: (ansi reset)"
        }

        az login --tenant $tenant_id

        let resource_group = $"dot-(date now | format date "%Y%m%d%H%M%S")"
        $"export RESOURCE_GROUP=($resource_group)\n" | save --append .env

        let location = "eastus"

        az group create --name $resource_group --location $location

        (
            az aks create --resource-group $resource_group --name dot
                --node-count $min_nodes --min-count $min_nodes
                --max-count $max_nodes
                --node-vm-size Standard_B2ms
                --enable-managed-identity --generate-ssh-keys
                --enable-cluster-autoscaler --yes
        )

        (
            az aks get-credentials --resource-group $resource_group
                --name dot --file $env.KUBECONFIG
        )
    
    } else {

        print $"(ansi red_bold)($hyperscaler)(ansi reset) is not a supported hyperscaler."
        exit 1

    }

    $env.KUBECONFIG

}

def destroy_kubernetes [hyperscaler: string] {

    if $hyperscaler == "google" {

        rm kubeconfig.yaml

        (
            gcloud container clusters delete dot
                --project $env.PROJECT_ID --zone us-east1-b --quiet
        )

        gcloud projects delete $env.PROJECT_ID --quiet
    
    } else if $hyperscaler == "aws" {

        (
            eksctl delete addon --name aws-ebs-csi-driver
                --cluster dot-production --region us-east-1
        )

        (
            eksctl delete nodegroup --name primary
                --cluster dot-production --drain=false
                --region us-east-1 --wait
        )

        (
            eksctl delete cluster
                --config-file eksctl-config.yaml --wait
        )

    } else if $hyperscaler == "azure" {

        az group delete --name $env.RESOURCE_GROUP --yes

    }

}
