# GKE Security Hardening & Zero-Trust Git Repository
## Platform + GKE + GCVE Security Triad Greenfield Cloud Migration

* ```created by @jsaccomani Google Cloud PSO AI & Infra Security LatAm ```
* ```Copyright (c) 2026 Joabson Saccomani. All rights reserved. ```

This repository contains the complete, production-ready, fully unified directory layout, documentation (`README.md`), and declarative configurations (Terraform HCL & Kubernetes YAML manifests) representing the **Enterprise Platform Golden Security Baseline**.

Designed to meet strict regulatory audits including **CIS GKE Benchmark v1.9.0**, **PCI-DSS v4.0 (CDE)**, and **NIST CSF 2.0**, this architecture establishes strong physical, logical, and semantic isolation across GKE clusters.

This repository explicitly integrates critical enterprise tooling: **Wiz** (AI-SPM, Unified Security Graph, Runtime Sensor, Wiz Defend), **Okta** (Directory identity syncing via GCDS), **Cortex XSIAM** (Centralized security logging/analytics target via Pub/Sub), and **Armo/Kubescape** (runtime behavioral modeling and RIP).

---

## Enterprise Multi-Tenant Architecture & Data Flow

This platform is structured on an identity-first, micro-segmented network fabric that restricts East-West lateral movement and enforces build-to-runtime integrity.

```text
               Google Cloud Armor Edge WAF (Ingress)
                                │
                                ▼
               GKE Inference Gateway (L7 Envoy Router)
                                │
                                ▼
         ┌──────────────────────────────────────────────┐
         │     Model Armor Inline Security Proxy        │
         └──────────────────────┬───────────────────────┘
                                │
                                ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ GKE Standard Cluster (payments-processing Namespace)         │
  │                                                             │
  │   ┌─────────────────────────────────────────────────────┐   │
  │   │  v1Serving Pod (Confidential Node, AMD SEV-SNP TEE) │   │
  │   │  - PSA: Restricted Profile                          │   │
  │   │  - GKE Sandbox / gVisor Runtime                     │   │
  │   │  - Strict mTLS Envoy Sidecar (CSM)                  │   │
  │   └────────┬───────────────────────────────────┬────────┘   │
  │            │ (Mount secrets to tmpfs)          │            │
  │            ▼                                   ▼            │
  │   ┌──────────────────┐               ┌──────────────────┐   │
  │   │ GCP SM CSI Volume│               │ GCS FUSE Mount   │   │
  │   │ (Secret Manager) │               │ (Model Weights)  │   │
  │   └──────────────────┘               └──────────────────┘   │
  │            ▲                                   ▲            │
  │            └─────────[ Workload Identity ]─────┘            │
  └─────────────────────────────────────────────────────────────┘
                                │
                                ▼ (Syscall Instrumentation)
  ┌─────────────────────────────────────────────────────────────┐
  │ Wiz Runtime eBPF Sensor DaemonSet                           │
  │ Armo/Kubescape Application Profile DNA RIP Agent            │
  └─────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Directory Tree

```
gke-security-hardening-baseline/
├── README.md                                 # Playbook, architecture, bootstrap & verification
├── bootstrap.sh                              # Complete, fully commented automation shell script
├── terraform/                                # Infrastructure as Code (GCP & GKE Core)
│   ├── providers.tf                          # Provider definitions & remote state blocks
│   ├── variables.tf                          # Global variables & subnet allocations
│   ├── gke-cluster.tf                        # Hardened GKE Standard, COS, and Shielded Nodes
│   ├── logging-sinks.tf                      # Folder-level log sinks to Cortex XSIAM
│   ├── org-policies.tf                       # Boolean constraints (Block keys, Cloud Shell)
│   ├── kms-keyring.tf                        # CMEK Keyrings & HSM-backed etcd/registry keys
│   ├── access-approval.tf                    # Access Approval & Essential Contacts
│   └── bigquery-audit-sink.tf                # BigQuery dataset & aggregated log sink
├── kubernetes/                               # Declarative Cluster State Manifests
│   ├── namespaces/
│   │   ├── payments-processing.yaml          # Restricted PSA Payments namespace
│   │   └── ai-inference.yaml                 # Sandboxed AI serving namespace
│   ├── policies/
│   │   ├── default-deny-netpolicy.yaml       # eBPF-powered default-deny-all NetworkPolicy
│   │   ├── metadata-gate-netpolicy.yaml      # eBPF-powered Metadata Server isolation
│   │   ├── gatekeeper-block-latest.yaml      # OPA Gatekeeper block-latest Constraint
│   │   └── kyverno/
│   │       └── mutate-pod-security.yaml      # Kyverno mutating policy for securityContext auto-injection
│   ├── storage/
│   │   ├── sm-secret-provider.yaml           # tmpfs SecretProviderClass for Secret Manager
│   │   ├── gcs-fuse-serving.yaml             # CSI Storage FUSE volume mapping (Model Weights)
│   │   └── hardened-ml-storage.yaml          # hyperdisk-ml StorageClass with CMEK
│   ├── security-partners/
│   │   ├── wiz-sensor-allowlist.yaml         # WorkloadAllowlist DaemonSet for GKE Autopilot
│   │   ├── armo-rip-profile.yaml             # Armo/Kubescape ApplicationProfile DNA CRD
│   │   └── dynamic-sandbox-pool.yaml         # SandboxTemplate and SandboxWarmPool (gVisor)
│   └── gitops/
│       └── argocd-application.yaml           # ArgoCD Application enforcing GitOps Self-Healing
├── manifests/                                # Edge, Routing & Workload Deployments
│   ├── ingress-cloud-armor.yaml             # BackendConfig and Ingress routing Cloud Armor
│   ├── inference-gateway-routes.yaml         # Envoy HTTPRoute with prefix-cache-aware GCAIP
│   └── gemma-secured-serving.yaml            # Serving deployment with Model Armor inline sidecar
└── kubernetes-scheduling/
    ├── kueue-gpu-queue.yaml                  # Kueue ClusterQueue/LocalQueue for GPU nodes
    └── gdc-bare-metal-cluster.yaml            # Hardened GDC Bare Metal local edge cluster spec
```

---

## Security Topics & Architectural Deep-Dives

The baseline enforces **26 integrated security topics**, organized across GKE and Google Cloud's native defense-in-depth security layers:

### 1. Network Policies (GKE Dataplane V2 / Cilium eBPF)
*   **Rationale**: Flat, unsegmented networks inside GKE allow compromised containers to perform internal reconnaissance, port sweeps, and lateral movement to reach adjacent pods or GKE API services.
*   **Technical Detail**: Built on eBPF (Extended Berkeley Packet Filter) and Cilium, GKE Dataplane V2 bypasses iptables entirely. Network policies are compiled directly into kernel bytecode and executed at the host kernel layer. We enforce a default-deny-all network policy, closing all traffic vectors unless explicitly authorized by declarative NetworkPolicies.

### 2. Binary Authorization (Supply Chain Gatekeeper)
*   **Rationale**: Software supply-chain compromises allow malicious actors to inject backdoored images into registries, which can bypass standard CI/CD pipelines to run in production.
*   **Technical Detail**: Binary Authorization acts as an admission controller inside GKE, validating container image signatures at deploy-time. We integrate this with Cloud KMS asymmetric keys, preventing the scheduling of any container unless a cryptographic attestation from our build pipeline is verified.

### 3. Cluster Pod Access (Workload Identity Federation)
*   **Rationale**: Injecting static, long-lived GCP Service Account JSON keys into containers creates a high risk of credential leakage via log files, code repositories, or compromised runtimes.
*   **Technical Detail**: Workload Identity Federation maps a Kubernetes Service Account (KSA) directly to a Google Cloud Service Account (GSA). The GKE Metadata Server runs as a DaemonSet, intercepting all requests directed to `169.254.169.254`. It validates the KSA's identity and exchanges its OIDC token for short-lived, self-rotating OAuth2 access tokens via the Google Security Token Service (STS).

### 4. Validate Workload Isolation (Container-Optimized OS / COS)
*   **Rationale**: Using general-purpose Linux node operating systems (such as Ubuntu or Debian) increases the host node's attack surface due to pre-installed packages, shells, and package managers.
*   **Technical Detail**: Container-Optimized OS (COS) is a minimal, Google-maintained, Chromium-based operating system designed specifically to run container workloads. The node root filesystem (`/`) is configured as **read-only**, and the kernel is stripped of unnecessary drivers, preventing persistent binary write attacks on GKE nodes.

### 5. Secure Host Boot & Shielded Nodes (Secure Boot, vTPM)
*   **Rationale**: If an attacker can inject malicious code into the node bootloader or hypervisor, they can compromise GKE nodes before the operating system or runtime security agents launch.
*   **Technical Detail**: Shielded GKE Nodes leverage a Virtual Trusted Platform Module (vTPM) and UEFI firmware to enable **Secure Boot** and **Measured Boot**. Secure Boot cryptographically verifies the signature of the bootloader, kernel, and system drivers against trusted Google keys. Measured Boot uses the vTPM to record a hash chain of the boot sequence, allowing continuous host integrity monitoring.

### 6. Strong Runtime Isolation (GKE Sandbox / gVisor)
*   **Rationale**: Container runtimes share the host VM's kernel namespaces. If a containerized process exploits a kernel vulnerability, it can break out of the container boundary and take over the host VM.
*   **Technical Detail**: GKE Sandbox uses **gVisor**, a lightweight user-space kernel written in Go. gVisor virtualizes system calls made by the application, running them in an isolated guest environment. If a compromised pod attempts a kernel exploit, it only damages the emulated gVisor kernel, protecting the underlying host node from compromise.

### 7. Pod Security Admission (Restricted Profile)
*   **Rationale**: Without admission-time enforcement, developers can deploy pods with dangerous security contexts, such as running as root, sharing the host namespace, or mounting raw node paths.
*   **Technical Detail**: Pod Security Admission (PSA) enforces Kubernetes **Pod Security Standards** natively at the namespace level. By applying the `restricted` profile, the admission controller blocks any pod that does not run as non-root, does not drop all default Linux capabilities, or attempts host-level resource sharing.

### 8. Secure Artifact Registry Storage & Continuous Vulnerability Scanning
*   **Rationale**: Vulnerabilities inside container images can be exploited post-deployment. Registries must be secure, private, and continuously scanned for new CVEs.
*   **Technical Detail**: Artifact Registry serves as our private container registry. It encrypts images in transit and at rest using KMS. The **Container Analysis API** is enabled in the project to run **Continuous Scanning**, which compares image layers against the National Vulnerability Database (NVD). If a new CVE is discovered in an active image, Artifact Registry immediately updates its security logs.

### 9. Software Bill of Materials (SBOM) Generation (Artifact Analysis)
*   **Rationale**: Organizations must maintain a complete inventory of the software dependencies inside their containers to detect compromised open-source packages.
*   **Technical Detail**: To automate SBOM visibility, GKE leverages the **Artifact Analysis API**. When an image is pushed to Artifact Registry, GKE parses the binary dependencies and generates a standard Software Bill of Materials (SBOM). This provides SecOps with immediate visibility into nested dependencies (such as log4j or OpenSSL versions) across the entire cluster.

### 10. End-to-End Build Provenance (Software Delivery Shield / SLSA L3)
*   **Rationale**: Attackers can attempt to compromise intermediate build artifacts during compilation. Provenance ensures that an image has been built strictly within a trusted, tamper-proof environment.
*   **Technical Detail**: **Software Delivery Shield** implements a secure build chain matching **SLSA Level 3** (Supply-chain Levels for Software Artifacts). Cloud Build compiles the container image and generates signed **Build Provenance** metadata. This immutable metadata proves where, when, and by whom the container was built, and is cryptographically verified by Binary Authorization at GKE admission time.

### 11. Secrets Management (GCP Secret Manager CSI Driver / tmpfs)
*   **Rationale**: Storing secrets in environment variables or standard Kubernetes Secrets is a major security anti-pattern, as they are exposed in plain-text inside etcd and are vulnerable to log leaks and memory scraping.
*   **Technical Detail**: The **Secret Manager CSI Driver** allows pods to retrieve secrets directly from GCP Secret Manager. At pod startup, the driver performs a Workload Identity handshake and mounts the requested secret as a volume. This volume is mounted exclusively under an in-memory **tmpfs** filesystem, ensuring the secret payload resides in volatile RAM and is never written to physical node disks.

### 12. Edge Security & Web Application Firewall (WAF via Cloud Armor)
*   **Rationale**: Public-facing GKE applications are exposed to Layer 7 attacks, such as SQL injection, cross-site scripting (XSS), and automated DDoS bots.
*   **Technical Detail**: To protect GKE ingress, we integrate **Google Cloud Armor** with GKE's Global External Application Load Balancer. Cloud Armor applies preconfigured rulesets (such as the OWASP Top 10) at the Google Edge, dropping malicious requests before they consume GKE cluster resources or enter the private VPC.

### 13. Threat Detection & Posture Management (GKE Posture Dashboard & SCC Premium)
*   **Rationale**: Platform teams must have continuous, real-time visibility into active misconfigurations, zero-day CVEs, and runtime container compromises.
*   **Technical Detail**: The **GKE Security Posture Dashboard** provides out-of-the-box visibility into cluster configuration drift. It is integrated with **Security Command Center (SCC) Premium**, which provides **Container Threat Detection (CTD)**. CTD monitors host kernel execution patterns, generating high-priority alerts for anomalies such as runtime binary modifications, execution of malicious scripts, or reverse shell spawns.

### 14. Control Plane Security & Private GKE Clusters (Disabled Public Endpoint)
*   **Rationale**: Exposing the Kubernetes API Server public endpoint to the internet allows bad actors to probe for access and launch brute-force attacks on the control plane.
*   **Technical Detail**: This architecture mandates a **Private GKE Cluster** with the public API endpoint disabled. The control plane VM and the worker nodes reside in private subnets with RFC 1918 IP addresses, communicating over private VPC peering tunnels. All public ingress routes to the API Server are removed.

### 15. Master Authorized Networks (MAN) Configuration
*   **Rationale**: Even on private networks, API Server access must be strictly limited to trusted subnets to prevent lateral escalation from compromised machines within the VPC.
*   **Technical Detail**: **Master Authorized Networks** act as a built-in firewall for the GKE API Server. It blocks all network handshakes attempting to reach the control plane unless they originate from explicitly whitelisted CIDR blocks, such as dedicated bastion hosts or secure CI/CD execution zones.

### 16. Administrative Access Proxying (Google Connect Gateway)
*   **Rationale**: Direct administration of private GKE clusters over VPNs or bastion hosts is hard to scale, log, and audit across multiple enterprise environments.
*   **Technical Detail**: The **Connect Gateway** acts as a secure, IAM-gated proxy for administrative GKE cluster access. SREs execute `kubectl` commands through the gateway, which integrates with Google Cloud IAM. This ensures that all cluster access requires multi-factor authentication (MFA) and is audited at the GCP level.

### 17. Data-at-Rest Encryption (Google-Managed Encryption Keys / GMEK)
*   **Rationale**: To prevent data exfiltration via physical disk theft, all cluster state and persistent storage disks must be encrypted.
*   **Technical Detail**: Google Cloud GKE Standard implements **Google-Managed Encryption Keys (GMEK)** by default. GMEK automatically encrypts all control plane disks, `etcd` state volumes, and persistent node disks at rest using 256-bit AES encryption. Keys are managed and rotated automatically by Google Cloud.

### 18. Data Exfiltration Prevention (VPC Service Controls / VPC-SC in Dry Run)
*   **Rationale**: Attackers who compromise a container with legitimate IAM permissions can exfiltrate sensitive data by writing to unapproved, external Cloud Storage buckets or BigQuery datasets.
*   **Technical Detail**: **VPC Service Controls (VPC-SC)** create a virtual security perimeter around your project resources. GKE is placed within this perimeter, restricting node API calls to authorized services. This architecture mandates running VPC-SC in **Dry Run** mode during initial deployment, allowing administrators to audit the perimeter against live workload profiles before switching to active blocking.

### 19. Automated GKE Lifecycle & Release Channels (Regular Channel)
*   **Rationale**: Running out-of-date Kubernetes versions exposes the cluster to known security vulnerabilities and increases configuration drift.
*   **Technical Detail**: The cluster is enrolled in the **Regular GKE Release Channel**. This ensures a balance between feature velocity and upgrade stability. Google automatically applies minor version upgrades and critical security patches to the control plane, keeping GKE aligned with stable upstream security standards.

### 20. Node Auto-Upgrades & Automated Maintenance Windows
*   **Rationale**: Nodes must be updated regularly to apply host OS patches, but these updates must not disrupt application availability.
*   **Technical Detail**: Node Pools are configured with **Node Auto-Upgrades** enabled, ensuring nodes are kept in sync with the control plane. SREs define **Maintenance Windows** and **Maintenance Exclusions** to schedule upgrades during low-traffic hours. Workloads use **PodDisruptionBudgets (PDB)** to prevent service disruption.

### 21. Audit Telemetry & Real-Time SIEM Integration (Logging to Cortex XSIAM via Pub/Sub)
*   **Rationale**: SecOps requires real-time log ingestion and correlation to detect and respond to active incidents across the enterprise.
*   **Technical Detail**: An aggregated Google Cloud Log Sink is configured to route all GKE audit logs (Admin Activity, Data Access) and GKE Dataplane V2 network drop events to a central Pub/Sub topic. This topic acts as the ingestion source for our enterprise **Cortex XSIAM** SIEM, where security analysts can correlate these signals with wider infrastructure telemetry.

### 22. Identity Governance & Directory-Based RBAC (GCDS Integration with Okta)
*   **Rationale**: Mapping RBAC permissions to individual user emails leads to privilege creep and makes access auditing difficult.
*   **Technical Detail**: **Google Cloud Directory Sync (GCDS)** synchronizes identities from our enterprise **Okta** directory service with Google Cloud Identity Groups. SREs bind GKE ClusterRoles to these synchronized Google Groups. When an employee leaves or changes roles, Okta revokes their group membership, immediately removing their access to the GKE cluster.

### 23. GKE Autopilot Partner Allowlisting (Wiz Runtime Sensor Support)
*   **Rationale**: GKE Autopilot blocks privileged DaemonSets by default to preserve node-host integrity. However, advanced cloud workload protection platforms (CWPP) require kernel-level visibility via eBPF sensors.
*   **Technical Detail**: We deploy GKE's native **WorkloadAllowlist** Custom Resource Definition (CRD). This registers the Wiz partner signature with GKE's admission controller, authorizing the GKE Warden to admit the privileged Wiz sensor DaemonSet on our managed nodes without compromising host security.

### 24. Kyverno (Policy-as-Code & Automated Mutation)
*   **Rationale**: Enforcing standard GKE hardening constraints (such as running containers as non-root, disabling privilege escalation, and deploying with a read-only root filesystem) can introduce significant build pipeline friction and deployment errors for application SRE teams. Requiring developers to manually configure deep securityContext keys for every deployment slows velocity and leads to admission webhook rejections.
*   **Technical Detail**: Kyverno is a native Kubernetes policy engine operating as a mutating and validating admission controller. In our baseline, Kyverno automatically mutates and injects standard `securityContext` settings (such as dropping all capabilities, setting readOnlyRootFilesystem, and forcing non-root runtimes) into workloads scheduled within CDE namespaces if omitted.

### 25. Log-Based Posture Auditing (BigQuery + Cloud Monitoring + Grafana)
*   **Rationale**: Preventative boundary controls successfully block unauthorized actions but do not provide analytics or audit records of blocked intrusion attempts.
*   **Technical Detail**: A folder-level log router sink aggregates and streams GKE Audit logs and Dataplane V2 drops directly into BigQuery. SREs leverage the BigQuery Grafana plugin to query and plot real-time security dashboard metrics, including: total pods blocked from executing as root, failed Secret Store CSI token handshakes, and network policy drop counts grouped by source IP.

### 26. GitOps Drift Detection & Self-Healing (ArgoCD)
*   **Rationale**: GitOps is the gold standard for deployment, but does not natively prevent direct cluster tampering via `kubectl edit` in runtime.
*   **Technical Detail**: ArgoCD continuously polls and diffs our repository against GKE. By enabling automated synchronization with both pruning and self-healing enabled (`prune: true`, `selfHeal: true`), ArgoCD instantly detects manual cluster drift (such as disabled NetworkPolicies) and rolls back GKE state to match our repository within seconds, locking down the cluster.

---

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

### Phase 2: Deploy KMS Enclaves, Log Routers & BigQuery Sinks
Provision the HSM-backed KMS Keyrings, BigQuery audit log datasets, and folder sinks routing to **Cortex XSIAM** and BigQuery:
```bash
terraform apply -target=google_kms_key_ring.hsm_keyring
terraform apply -target=google_bigquery_dataset.gke_security_dataset
terraform apply -target=google_pubsub_topic.xsiam_logs_topic
terraform apply -target=google_logging_folder_sink.aggregated_cortex_sink
terraform apply -target=google_logging_project_sink.bigquery_security_sink
```

### Phase 3: Provision GKE Standard Cluster & Nodes
Deploy the hardened GKE Standard cluster running on Container-Optimized OS with active Shielded instance configurations:
```bash
terraform apply -target=google_container_cluster.hardened_cluster
terraform apply -target=google_container_node_pool.primary_hardened_nodes
```

### Phase 4: Hydrate Cluster State, Install Kyverno & Setup ArgoCD Self-Healing
1. Authenticate to the private GKE cluster via bastion tunnel:
```bash
gcloud container clusters get-credentials hardened-gke-cluster --region us-central1-a
```
2. Run the automated bootstrapper to install Kyverno, setup ArgoCD, partition secure namespaces, and apply network/storage policies:
```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

---

## Verification & Troubleshooting Commands

### 1. GKE Dataplane V2 (Cilium/eBPF) Verification
Validate that GKE Dataplane V2 network policies are active and parsing kernel-level connection drops:
```bash
# Verify Cilium-specific GKE Dataplane V2 pods are running in kube-system
kubectl get pods -n kube-system -l k8s-app=cilium

# Audit eBPF network drop logs via cloud logging CLI filter
gcloud logging read 'resource.type="k8s_node" AND logName="projects/'$PROJECT_ID'/logs/dataplane-v2.drops"' --limit=10
```

### 2. Kyverno Mutation Audit
Confirm that Kyverno is successfully intercepting pod creations and injecting our securityContext baselines:
```bash
# Deploy an unhardened, basic pod spec
kubectl run unhardened-pod --image=nginx:alpine --namespace=payments-processing

# Inspect the scheduled pod's securityContext spec
kubectl get pod unhardened-pod -n payments-processing -o jsonpath='{.spec.containers[0].securityContext}'

# Expected Output: {"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true}
```

### 3. ArgoCD Drift Prevention Test
Verify that any manual drift injected via kubectl is instantly overwritten by ArgoCD:
```bash
# Attempt to manually delete the default-deny NetworkPolicy
kubectl delete networkpolicy default-deny-all -n payments-processing

# Immediately list network policies
kubectl get networkpolicies -n payments-processing

# Expected Behavior: ArgoCD detects the Out-of-Sync state and instantly recreates the resource.
```

### 4. BigQuery Posture Query Test
Confirm GKE audit events are reaching the BigQuery analytical dataset:
```bash
bq query --use_legacy_sql=false 'SELECT timestamp, logName, protoPayload.methodName FROM `'$PROJECT_ID'.gke_security_audit_logs.cloudaudit_googleapis_com_data_access_*` LIMIT 10'
```
