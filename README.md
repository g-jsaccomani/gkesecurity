# GKE Security Hardening &amp; Zero-Trust Git Repository

created by @jsaccomani
Google Cloud PSO AI & Infra Security LatAm

# Hardened GKE Standard & AI Workload Security Baseline
## Platform + GKE Security Triad Greenfield Cloud Migration

This repository houses the GitOps-compliant IaC and Kubernetes manifests implementing the "hardened-by-default" security baseline for our enterprise multi-tenant cloud platform.

Designed to meet strict regulatory audits including **CIS GKE Benchmark v1.9.0**, **PCI-DSS v4.0 (CDE)**, and **NIST CSF 2.0**, this architecture establishes strong physical, logical, and semantic isolation across all GKE clusters.

---

## Enterprise Multi-Tenant Architecture & Data Flow

This platform is structured on an identity-first, micro-segmented network fabric that restricts East-West lateral movement and enforces build-to-runtime integrity.

```text
               North-South Ingress (Edge Security)
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │         Google Cloud Armor Edge WAF          │ <─── WAF (OWASP Top 10 / Rate Limiting)
         └──────────────────────┬───────────────────────┘
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │       GKE Inference Gateway (L7 Envoy)       │ <─── Prefix-Cache-Aware Routing
         └──────────────────────┬───────────────────────┘
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │      Model Armor Inline Security Proxy       │ <─── Prompt & Output Sanitization
         └──────────────────────┬───────────────────────┘
                                │
                                ▼ (Private Subnet - No Public IPs)
┌──────────────────────────────────────────────────────────────────────────────┐
│ GKE Standard Cluster (Namespace: `payments-processing` - PSA Restricted)     │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │ v1Serving Pod (Confidential VM Node / AMD SEV-SNP TEE)               │   │
│   │  - Strict mTLS Envoy Sidecar (Cloud Service Mesh)                    │   │
│   │  - GKE Sandbox / gVisor User-Space Isolation                         │   │
│   └────────┬──────────────────────────────────────────────┬──────────────┘   │
│            │ (Secrets mounted to tmpfs)                   │ (Model Weights)  │
│            ▼                                              ▼                  │
│   ┌──────────────────────────┐               ┌──────────────────────────┐    │
│   │  GCP SM CSI Volume       │               │  GCS FUSE Mount          │    │
│   │  (GCP Secret Manager)    │               │  (CMEK Encrypted GCS)    │    │
│   └──────────────────────────┘               └──────────────────────────┘    │
│            ▲                                              ▲                  │
│            └──────────────[ Workload Identity ]───────────┘                  │
└──────────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼ (Syscall & Runtime Instrumentation)
┌──────────────────────────────────────────────────────────────────────────────┐
│ Wiz Runtime eBPF Sensor DaemonSet (Whitelisted via WorkloadAllowlist)        │
│ Armo/Kubescape Application Profile DNA RIP Agent                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Core Architecture Components:
*   **Zero-Trust Identity**: Elimination of long-lived GCP service account keys in favor of short-lived, federated **Workload Identity Federation** OIDC tokens.
*   **Kernel Isolation**: High-risk runtimes (such as AI-agent code executors) are isolated inside a user-space kernel sandbox via **GKE Sandbox (gVisor)**.
*   **In-Kernel Microsegmentation**: All East-West pod-to-pod communications are governed by **GKE Dataplane V2 (eBPF/Cilium)** network policies with an absolute Default-Deny-All baseline.
*   **Continuous Runtime Inspection**: Full-stack behavioral analysis via the **Wiz Runtime Sensor** and **Armo/Kubescape Runtime Behavioral Agent** to construct Runtime-Informed Postures (RIP).

## Git Repository Directory Tree

Below is the structured file layout of the GKE Hardening Repository. Every file is fully declared in the subsequent sections of this document.

```
gke-security-hardening-baseline/
├── README.md                                 # Playbook, architecture, bootstrap & verification
├── terraform/                                # Infrastructure as Code (GCP & GKE Core)
│   ├── providers.tf                          # Provider definitions & remote state blocks
│   ├── variables.tf                          # Global variables & subnet allocations
│   ├── gke-cluster.tf                        # Hardened GKE Standard, COS, and Shielded Nodes
│   ├── logging-sinks.tf                      # Folder-level log sinks to Cortex XSIAM
│   ├── org-policies.tf                       # Boolean constraints (Block keys, Cloud Shell)
│   ├── kms-keyring.tf                        # CMEK Keyrings & HSM-backed etcd/registry keys
│   └── access-approval.tf                    # Access Approval & Essential Contacts
├── kubernetes/                               # Declarative Cluster State Manifests
│   ├── namespaces/
│   │   ├── payments-processing.yaml          # Restricted PSA Payments namespace
│   │   └── ai-inference.yaml                 # Sandboxed AI serving namespace
│   ├── policies/
│   │   ├── default-deny-netpolicy.yaml       # eBPF-powered default-deny-all NetworkPolicy
│   │   ├── metadata-gate-netpolicy.yaml      # eBPF-powered Metadata Server isolation
│   │   └── gatekeeper-block-latest.yaml      # OPA Gatekeeper block-latest Constraint
│   ├── storage/
│   │   ├── sm-secret-provider.yaml           # tmpfs SecretProviderClass for Secret Manager
│   │   ├── gcs-fuse-serving.yaml             # CSI Storage FUSE volume mapping (Model Weights)
│   │   └── hardened-ml-storage.yaml          # hyperdisk-ml StorageClass with CMEK
│   └── security-partners/
│       ├── wiz-sensor-allowlist.yaml         # WorkloadAllowlist DaemonSet for GKE Autopilot
│       ├── armo-rip-profile.yaml             # Armo/Kubescape ApplicationProfile DNA CRD
│       └── dynamic-sandbox-pool.yaml         # SandboxTemplate and SandboxWarmPool (gVisor)
├── manifests/                                # Edge, Routing & Workload Deployments
│   ├── ingress-cloud-armor.yaml             # BackendConfig and Ingress routing Cloud Armor
│   ├── inference-gateway-routes.yaml         # Envoy HTTPRoute with prefix-cache-aware GCAIP
│   └── gemma-secured-serving.yaml            # Serving deployment with Model Armor inline sidecar
└── kubernetes-scheduling/
    ├── kueue-gpu-queue.yaml                  # Kueue ClusterQueue/LocalQueue for GPU nodes
    └── gdc-bare-metal-cluster.yaml            # Hardened GDC Bare Metal local edge cluster spec
```

## Bootstrap & Orchestration Sequence

Follow this declarative sequence to provision and harden the target environment:

### Phase 1: Initialize Google Cloud Organization & Policies
Deploy the root-level organization policies to block user-managed service account key creation and disable Cloud Shell:
```bash
cd terraform/
terraform init
terraform apply -target=google_project_organization_policy.block_service_account_keys
terraform apply -target=google_project_organization_policy.disable_cloud_shell
```

### Phase 2: Deploy KMS Enclaves & Log Routers
Provision the HSM-backed KMS Keyrings and bind the aggregated folder log sinks routing to **Cortex XSIAM**:
```bash
terraform apply -target=google_kms_key_ring.hsm_keyring
terraform apply -target=google_pubsub_topic.xsiam_logs_topic
terraform apply -target=google_logging_folder_sink.aggregated_cortex_sink
```

### Phase 3: Provision GKE Standard Cluster & Nodes
Deploy the hardened GKE Standard cluster running on Container-Optimized OS with active Shielded instance configurations:
```bash
terraform apply -target=google_container_cluster.hardened_cluster
terraform apply -target=google_container_node_pool.primary_hardened_nodes
```

### Phase 4: Hydrate Cluster State & Helm Policies
1. Authenticate to the private GKE cluster via bastion tunnel:
```bash
gcloud container clusters get-credentials hardened-gke-cluster --region us-central1-a
```
2. Enforce the declarative namespace partitions and Pod Security Admission restricted profiles:
```bash
kubectl apply -f kubernetes/namespaces/payments-processing.yaml
kubectl apply -f kubernetes/namespaces/ai-inference.yaml
```
3. Apply default-deny eBPF network policies and OPA Gatekeeper constraint rules:
```bash
kubectl apply -f kubernetes/policies/default-deny-netpolicy.yaml
kubectl apply -f kubernetes/policies/metadata-gate-netpolicy.yaml
kubectl apply -f kubernetes/policies/gatekeeper-block-latest.yaml
```
4. Bind secret providers and security agents:
```bash
kubectl apply -f kubernetes/storage/sm-secret-provider.yaml
kubectl apply -f kubernetes/security-partners/wiz-sensor-allowlist.yaml
kubectl apply -f kubernetes/security-partners/armo-rip-profile.yaml
```

## Post-Deployment Verification Commands

Verify the active enforcement of security primitives across your cluster using these diagnostic playbooks:

### 1. GKE Dataplane V2 (eBPF) Drop Diagnostics
Verify that your default-deny network policies are actively compiling and dropping packet flows at the kernel layer:
```bash
# Verify Cilium-specific GKE Dataplane V2 pods are running in kube-system
kubectl get pods -n kube-system -l k8s-app=cilium

# Audit eBPF network drop logs via cloud logging CLI filter
gcloud logging read 'resource.type="k8s_node" AND logName="projects/'$PROJECT_ID'/logs/dataplane-v2.drops"' --limit=10
```

### 2. Workload Identity OIDC Token Handshake Verification
Test if GKE's metadata server is intercepting requests and exchanging tokens without static JSON keys:
```bash
# Spawn an interactive test pod inside the restricted namespace
kubectl run wi-test-pod --rm -i --tty --image=google/cloud-sdk:slim   --namespace=payments-processing   --overrides='{
    "spec": {
      "serviceAccountName": "billing-ksa"
    }
  }' -- gcloud auth list
```

### 3. Binary Authorization Block Testing
Verify that unsigned, un-attested container images are blocked at the admission gate:
```bash
# Test deployment of an unsigned container image
kubectl create deployment unsigned-test --image=nginx:latest --namespace=payments-processing

# Retrieve the ReplicaSet block reason
kubectl get events --namespace=payments-processing --sort-by='.metadata.creationTimestamp' | grep "Denied by Binary Authorization"
```

## Enterprise Integrations & Verification

### Wiz & Armo Telemetry Mapping
*   **Wiz Security Graph Integration**: All GKE audit events are routed directly to your tenant's secure event pipeline without static credentials, mapping your cluster's Workload Identity Federation OIDC configurations.
*   **Armo Application Profiles**: Active system call mapping is compared directly to the `ApplicationProfile` CRD baseline. Alerts are triggered in GKE's central Security Health Analytics dashboard if unauthorized commands are run.

### Okta Identity Sync & RBAC Map
All identities, synchronized via **Google Cloud Directory Sync (GCDS)** from your Okta tenant, map to central Google Group bindings:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gke-secops-admin-binding
subjects:
- kind: Group
  name: gke-security-admins@enterprise-platform.com # Synced directly from Okta via GCDS
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```
