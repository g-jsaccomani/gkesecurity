#!/bin/bash
set -euo pipefail

# Hardened Greenfield Platform Bootstrapper
# Enforces CIS, PCI-DSS v4.0, and NIST CSF 2.0 Policies
echo "=========================================================="
echo "Starting Greenfield GKE Security Hardening Bootstrapper..."
echo "=========================================================="

# 1. Dependency Checks
echo "Checking local environment dependencies..."
for cmd in kubectl helm terraform openssl; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Required command '$cmd' is not installed." >&2
        exit 1
    fi
done
echo "All local dependencies verified."

# 2. Applying Terraform Organization Policies and BigQuery Sinks
echo "Executing Phase 1 & 2: Terraform Infrastructure Deployment..."
cd terraform/
terraform init
terraform apply -auto-approve
cd ../

# 3. Apply Secure Declarative Namespaces
echo "Hydrating GKE Namespace boundaries and PSA restricted labels..."
kubectl apply -f kubernetes/namespaces/payments-processing.yaml
kubectl apply -f kubernetes/namespaces/ai-inference.yaml

# 4. Apply Network Segmentation & Baseline Security Policies
echo "Applying eBPF network perimeters and baseline Gatekeeper rules..."
kubectl apply -f kubernetes/policies/default-deny-netpolicy.yaml
kubectl apply -f kubernetes/policies/metadata-gate-netpolicy.yaml
kubectl apply -f kubernetes/policies/gatekeeper-block-latest.yaml

# 5. Installing Kyverno (Policy-as-Code Engine)
echo "Installing Kyverno policy engine via Helm..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace --set admissionController.replicas=3

echo "Waiting for Kyverno webhook receiver..."
kubectl rollout status deployment/kyverno -n kyverno --timeout=90s

echo "Applying automated Pod hardening Mutation policies..."
kubectl apply -f kubernetes/policies/kyverno/mutate-pod-security.yaml

# 6. Apply Storage Class CMEK & Secrets CSI Configuration
echo "Deploying hardware-encrypted storage classes and CSI providers..."
kubectl apply -f kubernetes/storage/sm-secret-provider.yaml
kubectl apply -f kubernetes/storage/hardened-ml-storage.yaml

# 7. Installing ArgoCD and Enabling Self-Healing GitOps
echo "Installing ArgoCD and bootstrapping GitOps pipelines..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD Application controller..."
kubectl rollout status deployment/argocd-application-controller -n argocd --timeout=90s

echo "Enforcing absolute repository state and enabling Self-Healing..."
kubectl apply -f kubernetes/gitops/argocd-application.yaml

echo "=========================================================="
echo "Greenfield GKE Security Hardening Bootstrap Completed!"
echo "=========================================================="
