# Trust No Pipeline: Securing Software Delivery & Workload Identity in the Cloud

> **Speaker & Live Demo Repository (Google Cloud + GKE Edition)**  
> Companion repository & live attack/defense testbed for the session **"Trust No Pipeline: Securing Software Delivery and Workload Identity in the Cloud"**.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/calganaygun/trust-no-pipeline-gcp-demo.git&cloudshell_tutorial=README.md)

---

## ☁️ Google Cloud Shell Quickstart (1-Command Setup)

Click the **Open in Cloud Shell** badge above or open **Activate Cloud Shell (`>_`)** in the Google Cloud Console and run:

```bash
git clone https://github.com/calganaygun/trust-no-pipeline-gcp-demo.git && \
cd trust-no-pipeline-gcp-demo && \
./scripts/01-setup-gcp-guardrails.sh
```

This bootstrap script automatically detects your active GCP project in Cloud Shell and provisions:
1. Required Google Cloud APIs (`iam`, `sts`, `artifactregistry`, `cloudbuild`, `binaryauthorization`, `containerscanning`).
2. A dedicated CI Service Account (`ci-prod-deployer`) and enforces `constraints/iam.disableServiceAccountKeyCreation` (blocks static JSON key creation).
3. A **Workload Identity Pool** (`github-prod-pool`) and a **CEL-locked OIDC Provider** (`github-oidc-provider`) requiring `repository_owner_id`, `refs/heads/main`, and `github-hosted` runners.
4. An **Artifact Registry** repository (`prod-containers`) with **Immutable Tags** (`--immutable-tags`) enabled and bound directly to the federated identity (`principalSet://...`).
5. A sample container build (`payments-api:v1.0.0`) submitted via regional **Cloud Build** to generate verifiable **SLSA Level 3 Provenance**.

Once the bootstrap completes, launch the interactive **5-Scenario Live Attack Simulator**:
```bash
./scripts/02-run-attack-vectors.sh
```

*(Tip: To preview the interactive HTML slide deck directly from Cloud Shell, run `python3 -m http.server 8080` and click **Web Preview → Preview on port 8080**.)*

---

## 📂 Repository Structure (Turnkey Demo Project)

```text
.
├── index.html                                    # 🎪 Interactive Visual HTML Slide Deck (11 Slides)
├── README.md                                     # 📖 Complete Speaker Runbook, GCP UIs & CLI Guide
├── .github/workflows/
│   ├── deploy-hardened.yml                       # ✅ Hardened CI/CD: SHA-pinned, --ignore-scripts, WIF + SLSA L3
│   └── attack-sim-oidc-hijack.yml                # 🚨 Attack Simulator: PR / Non-Main OIDC Hijack (Fails at GCP STS!)
├── app/
│   ├── main.py                                   # 🐍 Zero-Trust Demo Microservice (GKE Metadata Token Introspection)
│   └── Dockerfile                                # 📦 Digest-pinned, non-root (UID 65532) container build
├── attack-vectors/
│   └── chaindrop-sim/                            # 🐛 Safe ChainDrop (Aug 2026) / Shai-Hulud preinstall worm simulator
│       ├── package.json                          #    Triggers 'preinstall: node setup.mjs'
│       ├── setup.mjs                             #    Simulates process.env secret scraping (redacted)
│       └── .npmrc.hardened                       #    Hardened 'ignore-scripts=true' guard
├── k8s/
│   ├── namespace-and-ksa.yaml                    # 🪪 K8s Namespace + ServiceAccount for Direct GKE WIF
│   ├── deployment-hardened.yaml                  # 🛡️ Digest-pinned, read-only rootfs, non-root GKE Deployment
│   └── rogue-pod-attack.yaml                     # 🏴‍☠️ Unsigned Pod manifest (Blocked by GKE Binary Authorization!)
└── scripts/
    ├── 00-env.sh                                 # 🔧 Shared GCP Project & GitHub Repo environment config
    ├── 01-setup-gcp-guardrails.sh                # 🚀 Automated GCP setup (Org Policy, CEL WIF, GAR, Binary Auth)
    └── 02-run-attack-vectors.sh                  # 🔥 Interactive 5-Scenario Live Attack Simulator (Watch them FAIL!)
```

---

## ⚡ Quickstart: Running the Live Attack Simulator on Stage

Want to show 5 real-world supply chain & cloud identity attacks **failing live** against your guardrails? Run:

```bash
# 1. (Optional) Bootstrap your GCP project guardrails first:
./scripts/01-setup-gcp-guardrails.sh

# 2. Launch the interactive 5-step Attack Vector Simulator:
./scripts/02-run-attack-vectors.sh
```

### What `./scripts/02-run-attack-vectors.sh` Demos Live:
1. **Attack 1 (`ChainDrop` & `Shai-Hulud` npm `preinstall` Worm)**: Runs `npm install` in `attack-vectors/chaindrop-sim` (triggers `setup.mjs` environment scan & fails with exit code 1) vs. hardened `npm install --ignore-scripts` (neutralized!).
2. **Attack 2 (Vampire Static JSON Key Minting)**: Runs `gcloud iam service-accounts keys create /tmp/backdoor-key.json` → **FAILS** against `constraints/iam.disableServiceAccountKeyCreation`.
3. **Attack 3 (`Mini Shai-Hulud` / `Nx` PR & Rogue Runner OIDC Hijack)**: Sends a forged/PR OIDC token (`ref: refs/pull/99/merge`, `runner_environment: self-hosted`) to `https://sts.googleapis.com/v1/token` → **FAILS** at the Google Cloud STS boundary!
4. **Attack 4 (`tj-actions` Style Mutable Tag Overwrite)**: Attempts to overwrite an existing `:v1.0.0` release tag → **FAILS** against Artifact Registry `--immutable-tags`.
5. **Attack 5 (Rogue Unattested Container on GKE)**: Runs `kubectl apply -f k8s/rogue-pod-attack.yaml` → **FAILS** at the GKE **Binary Authorization** admission webhook (`No valid SLSA Level 3 attestation found`)!

---

## 🖥️ 1. Opening the Interactive HTML Slide Deck

Open [`index.html`](./index.html) directly in any modern browser (Chrome, Edge, Firefox, Safari):

```bash
open index.html
```

### Slide Deck Keyboard Shortcuts & Interactive Features
- **`→` / `Space` / `PageDown`**: Next slide (triggers staggered entry & pipeline packet animations)
- **`←` / `PageUp`**: Previous slide
- **`N`**: Toggle the **Speaker Notes Drawer** (bottom-right overlay with talking points per slide)
- **`G`**: Toggle the **Slide Overview Grid** to jump directly to any slide
- **`F`**: Toggle **Fullscreen Presentation Mode**
- **Slide 6 Interactive Toggle**: Switch live between the **❌ Vulnerable WIF Config** and **✅ Hardened CEL-Locked WIF Config** during your talk.

---

## 📰 2. Latest Real-World Supply Chain & CI/CD Identity Attacks (2025–2026)

Use these recent, high-impact incidents to show the audience **how trust in software delivery systems is abused in practice**, followed immediately by **what stops them on Google Cloud**.

---

### Incident 1: The `tj-actions/changed-files` & `reviewdog` Cascade (March 2025)
- **Identifiers**: **CVE-2025-30066** (`tj-actions/changed-files`) & **CVE-2025-30154** (`reviewdog/action-setup`)
- **Scale / News Headline**: Over **23,000+ GitHub repositories** impacted via mutable version tag hijacking.
- **How the Attack Worked**:
  1. Attackers exploited an unsafe workflow in SpotBugs to compromise a Personal Access Token (PAT) and poison `reviewdog/action-setup@v1`.
  2. Using a stolen bot token, attackers retroactively repointed **every mutable version tag (`@v1` through `@v45.0.7`)** of `tj-actions/changed-files` to a malicious commit.
  3. Whenever a victim's CI workflow ran, the injected payload executed a Python script (`memdump.py`) that read `/proc/$pid/mem` of the `Runner.Worker` process and dumped cleartext secrets (GCP Service Account JSON keys, AWS keys, npm tokens, GitHub tokens) straight into build logs.
- **What Fixes It on Google Cloud & CI/CD**:
  1. **CI/CD**: Pin third-party GitHub Actions to full 40-character immutable commit SHAs (`uses: tj-actions/changed-files@<40-char-sha>`), never floating tags (`@v45`).
  2. **GCP Identity**: Eliminate static Service Account JSON keys (`constraints/iam.disableServiceAccountKeyCreation`) and use **Workload Identity Federation (WIF)** with short-lived (15–60 min) OAuth tokens. Even if runner memory is dumped into public logs, the token expires rapidly and cannot be used years later.
  3. **GCP Network Perimeter**: Wrap sensitive GCP projects in **VPC Service Controls (VPC-SC)** with context-aware ingress rules so a stolen token cannot be replayed from an attacker's workstation IP.

---

### Incident 2: Nx Build System (`s1ngularity`) & `pull_request_target` Injection (August 2025)
- **Scale / News Headline**: Compromised `nx` npm packages (`21.x` / `20.x`) published after attackers exploited `pull_request_target` workflow injection to mint privileged tokens; subsequent payload harvested developer cloud credentials and local CLI tokens across thousands of developer machines.
- **How the Attack Worked**:
  1. A GitHub Actions workflow triggered via `pull_request_target` (which runs in the context of the base repository and has access to secrets and `id-token: write` OIDC permissions) processed untrusted input/code from an external pull request.
  2. Attackers injected commands to steal publishing & cloud tokens, pushing trojanized package versions to npm.
- **The Cloud OIDC Twist ("Over-Broad WIF Trust Policies")**:
  - Many organizations migrated away from static JSON keys to **Workload Identity Federation (OIDC)**, thinking they were safe.
  - However, they configured their GCP WIF Provider to check **only** `assertion.repository == 'org/repo'` (or worse, only `assertion.repository_owner == 'org'`).
  - Because `pull_request_target` or unmerged feature branches still carry `"repository": "org/repo"` in their OIDC JWT claims, **an untrusted PR or feature branch can mint production GCP tokens!**
- **What Fixes It on Google Cloud**:
  1. **Strict CEL Attribute Conditions on GCP WIF**: Enforce a Common Expression Language (CEL) condition on the Workload Identity Provider that checks:
     - Numeric `assertion.repository_owner_id` (immutable against org renames)
     - Exact `assertion.repository`
     - Protected branch `assertion.ref == 'refs/heads/main'`
     - Event type `assertion.event_name == 'push'` (or `'workflow_dispatch'`)
     - Exact workflow file `assertion.job_workflow_ref`
  2. **Environment-Scoped Service Accounts / Principals**: Separate the read-only `terraform plan` identity (allowed on PRs) from the `terraform apply` / GKE deploy identity (restricted to the `production` GitHub Environment with required human reviewers).

---

### Incident 3: The `Shai-Hulud` Evolution — `Shai-Hulud 2.0` (Nov 2025) & `Mini Shai-Hulud` (May 2026)
- **Scale / News Headline**: Self-replicating supply chain worms across npm and CI/CD pipelines.
  - **Wave 1 & 2 (`Shai-Hulud 2.0` / "The Second Coming", Sept–Nov 2025)**: Executed in `preinstall` hooks, ran embedded **TruffleHog** scanners to harvest cloud credentials (`GOOGLE_CREDENTIALS`, AWS keys, Vault tokens), automatically republished trojanized versions of every package owned by the victim, and registered persistent rogue self-hosted GitHub Actions runners named **`SHA1HULUD`**.
  - **Wave 3 (`Mini Shai-Hulud`, May 2026)**: A streamlined variant triggered via `pull_request_target` ("pwn requests"), poisoning `pnpm` caches, dumping **OIDC tokens directly from CI runner memory**, and hitting major ecosystems (including TanStack, Mistral AI, and UiPath).
- **Links to Show Live**:
  - [Wiz Research: Shai-Hulud Supply Chain Worm](https://www.wiz.io/blog/shai-hulud-npm-supply-chain-attack)
  - [Panther Labs: Shai-Hulud Analysis](https://panther.com/blog/shai-hulud-npm-supply-chain-attack)
  - [2026 npm Worm Defense Analysis](https://hackstacksecure.com/blogs/npm-worm-supply-chain-defense-2026/)
  - [Aikido Report: Credential-Stealing Worm](https://www.aikido.dev/blog/red-hat-npm-packages-compromised-credential-stealing-worm)
- **What Fixes It on Google Cloud & GKE**:
  1. **Block Rogue Self-Hosted Runners in GCP WIF**: Because `Shai-Hulud 2.0` registers a rogue self-hosted runner (`SHA1HULUD`), your GCP Workload Identity Provider CEL condition **must** assert `assertion.runner_environment == 'github-hosted'` (or verify your isolated VPC runner pool).
  2. **Block `pull_request_target` OIDC Minting (`Mini Shai-Hulud`)**: Require `assertion.ref == 'refs/heads/main' && assertion.event_name == 'push'` in your GCP WIF CEL condition so pwn-requests cannot exchange OIDC tokens.

---

### Incident 4: `ChainDrop` Worm (August 4, 2026)
- **Scale / News Headline**: Compromised core JavaScript maintainer accounts—most notably **`keyv`** (`flat-cache`, `cacheable-request`)—infecting **400+ unique npm packages** (1,300+ versions, billions of monthly downloads).
- **How the Attack Worked**:
  1. **Install-Time Bun Dropper**: Used `preinstall` hooks (`setup.mjs`) to drop an obfuscated **Bun** runtime payload across Linux, macOS, and Windows.
  2. **Ethereum Smart Contract C2 ("EtherHiding")**: Routed Command-and-Control instructions via Ethereum smart contracts to evade corporate DNS/domain blocklists.
  3. **Automated Worm Propagation & Cloud Theft**: Committed malicious updates with dummy author `claude` (`chore: update config`), scraping GitHub Actions OIDC tokens, Kubernetes configs, HashiCorp Vault tokens, and cloud keys.
  4. **Why SLSA Level 2 Failed**: Because `ChainDrop` compromised the maintainer's credentials *before* the build, standard SLSA Level 2 provenance still passed—proving why organizations need **isolated SLSA Level 3 builders** + strict admission controls.
- **Links to Show Live**:
  - [Elastic Security Labs: Shai-Hulud & ChainDrop Analysis](https://www.elastic.co/security-labs/threat-command/shai-hulud-chaindrop-npm-supply-chain)
  - [Palo Alto Unit 42: ChainDrop npm Worm Analysis](https://unit42.paloaltonetworks.com/chaindrop-npm-worm-analysis/)
  - [StepSecurity: ChainDrop Incident Breakdown](https://www.stepsecurity.io/blog/chaindrop-npm-worm)
  - [GitGuardian: GhostAction 3,000+ Secrets Stolen](https://blog.gitguardian.com/ghostaction-campaign-3-000-secrets-stolen/)
- **What Fixes It on Google Cloud & GKE**:
  1. **Artifact Registry Immutable Tags**: Prevent attackers from overwriting `:v1.4.2` or `:prod` tags with a trojanized image.
  2. **SLSA Level 3 Isolated Provenance (Google Cloud Build)**: Build in hermetic/isolated regional Cloud Build workers (`--ignore-scripts` for untrusted lifecycle hooks) rather than local developer laptops.
  3. **GKE Binary Authorization + VPC Service Controls**: Reject any container image lacking a valid cryptographic attestation from your trusted Attestor, and block exfiltrated tokens from being replayed outside your VPC perimeter.

---

## 🛠️ 3. GCP Console UIs & Live CLI Commands Runbook

Below is the step-by-step guide of **what to show in the Google Cloud Console UI** and **which CLI commands to run** during your session.

### Environment Setup (Run Before Session)
```bash
export PROJECT_ID="your-gcp-project-id"
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export REGION="us-central1"
export CLUSTER_NAME="prod-gke-cluster"
export GITHUB_ORG_ID="12345678"          # Numeric GitHub Organization ID
export GITHUB_REPO="acme-corp/payments-api"

gcloud config set project "$PROJECT_ID"
```

---

### Demo Part 1: Auditing & Killing Long-Lived Service Account Keys

#### 🖥️ GCP Console UI to Show Live:
1. Navigate to **IAM & Admin → Service Accounts**.
2. Click on a CI/CD service account → open the **Keys** tab to show user-managed keys with expiration set to `Dec 31, 9999`.
3. Click the **Metrics** tab (or go to **IAM & Admin → Policy Intelligence / Recommender**) to show **Key Last Used** timestamps and unused privilege recommendations.
4. Navigate to **IAM & Admin → Organization Policies** and search for:
   - `iam.disableServiceAccountKeyCreation` (*Disable service account key creation*)
   - `iam.disableServiceAccountKeyUpload` (*Disable service account key upload*)

#### 💻 CLI Commands to Run:
```bash
# 1. Discover all user-managed (downloadable JSON) keys across a Service Account
gcloud iam service-accounts keys list \
  --iam-account="ci-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --managed-by=user \
  --format="table(name.basename(), validAfterTime, validBeforeTime, keyAlgorithm)"

# 2. Check Cloud Audit Logs / Recommender insights for unused service accounts or keys
gcloud recommender insights list \
  --project="$PROJECT_ID" \
  --location=global \
  --insight-type=google.iam.serviceAccount.Insight

# 3. Enforce Organization Policy to block static Service Account key creation
cat <<EOF > disable-sa-keys.yaml
name: projects/${PROJECT_ID}/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
  - enforce: true
EOF

gcloud org-policies set-policy disable-sa-keys.yaml
```

---

### Demo Part 2: Workload Identity Federation (WIF) — Vulnerable vs. Hardened

#### 🖥️ GCP Console UI to Show Live:
1. Navigate to **IAM & Admin → Workload Identity Federation**.
2. Open your Pool (`github-actions-pool`) → click **Providers** → click **Edit** on the GitHub OIDC provider.
3. Highlight the **Attribute Mapping** fields (`google.subject`, `attribute.repository`, `attribute.workflow_ref`).
4. Highlight the **Attribute Conditions (CEL)** box—explain why leaving this blank or only checking `repository` allows any PR/branch to hijack cloud access.

#### 💻 CLI Commands to Run:

```bash
# 1. Create a Workload Identity Pool for CI/CD
gcloud iam workload-identity-pools create "github-prod-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Prod Pool"

# 2. Create a HARDENED OIDC Provider with a strict CEL --attribute-condition
gcloud iam workload-identity-pools providers create-oidc "github-oidc-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-prod-pool" \
  --display-name="GitHub Actions Hardened OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref,attribute.workflow_ref=assertion.job_workflow_ref" \
  --attribute-condition="assertion.repository_owner_id == '${GITHUB_ORG_ID}' && assertion.repository == '${GITHUB_REPO}' && assertion.ref == 'refs/heads/main' && assertion.event_name == 'push' && assertion.runner_environment == 'github-hosted'"
```

#### Modern Direct Federated Principal IAM Binding (No Service Account Needed!):
```bash
# Grant Artifact Registry Writer directly to the federated identity from the main branch
gcloud artifacts repositories add-iam-policy-binding "prod-containers" \
  --location="${REGION}" \
  --role="roles/artifactregistry.writer" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-prod-pool/attribute.repository/${GITHUB_REPO}"
```

#### Hardened GitHub Actions Workflow Snippet (`.github/workflows/deploy.yml`):
```yaml
name: Build and Deploy to GKE
on:
  push:
    branches: [ "main" ]

# Global default: least privilege
permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      id-token: write # Required ONLY on the job that exchanges OIDC tokens
    steps:
      # Always pin actions to a full 40-character commit SHA (prevents CVE-2025-30066)
      - name: Checkout Source
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Authenticate to Google Cloud via WIF (Direct Principal)
        uses: google-github-actions/auth@6fc4af4b145ae7821d527454aa9bd537d1f2dc5f # v2.1.7
        with:
          workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/github-prod-pool/providers/github-oidc-provider"
          token_format: "access_token"
```

---

### Demo Part 3: GKE Workload Identity Federation for Kubernetes

#### 🖥️ GCP Console UI to Show Live:
1. Navigate to **Kubernetes Engine → Clusters → [Your Cluster] → Security** tab.
2. Point out **Workload Identity: Enabled (`<PROJECT_ID>.svc.id.goog`)**.
3. Click **Nodes** tab → open the Node Pool → show **GKE Metadata Server: Enabled** and verify that the Node Pool does **not** use the legacy Compute Engine default service account with `cloud-platform` full access scope.

#### 💻 CLI Commands to Run:

```bash
# 1. Create a dedicated Kubernetes Namespace and Kubernetes ServiceAccount (KSA)
kubectl create namespace payments-prod
kubectl create serviceaccount checkout-ksa --namespace payments-prod

# 2. MODERN APPROACH: Bind the Kubernetes ServiceAccount DIRECTLY to a GCP Secret or Bucket
#    (No intermediate GCP Service Account required!)
gcloud secrets add-iam-policy-binding "stripe-webhook-secret" \
  --role="roles/secretmanager.secretAccessor" \
  --member="principal://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${PROJECT_ID}.svc.id.goog/subject/ns/payments-prod/sa/checkout-ksa"

# 3. Deploy a test pod running as checkout-ksa and verify its identity via GKE Metadata Server
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: identity-verify-pod
  namespace: payments-prod
spec:
  serviceAccountName: checkout-ksa
  containers:
  - name: sdk
    image: gcr.io/google.com/cloudsdktool/google-cloud-cli:slim
    command: ["sleep", "3600"]
EOF

# 4. Exec into the pod and inspect the short-lived token issued by GKE Metadata Server
kubectl exec -it identity-verify-pod -n payments-prod -- \
  curl -s -H "Metadata-Flavor: Google" \
  "http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token"
```

---

### Demo Part 4: Artifact Provenance (SLSA Level 3), Immutable Tags & Binary Authorization

#### 🖥️ GCP Console UI to Show Live:
1. Navigate to **Artifact Registry → Repositories → [Your Docker Repo]**.
   - Show **Immutable image tags: Enabled**.
   - Click into a container image digest (`@sha256:...`) → open the **Build Provenance** tab to display the verified **SLSA Build Level 3** attestation JSON, builder identity, and source commit link.
   - Open the **Vulnerabilities** tab to show automated CVE scanning results.
2. Navigate to **Security → Binary Authorization**.
   - Show the **Policy** tab: Default rule set to **Require attestation** by `prod-ci-attestor`.
3. Navigate to **Kubernetes Engine → Workloads** or **Logging → Logs Explorer** to show the Binary Authorization admission webhook blocking an unsigned image deployment in real time.

#### 💻 CLI Commands to Run:

```bash
# 1. Create an Artifact Registry repository with IMMUTABLE TAGS enabled
gcloud artifacts repositories create prod-containers \
  --repository-format=docker \
  --location="${REGION}" \
  --immutable-tags \
  --description="Production container registry with immutable tags"

# 2. Submit a build via Cloud Build (automatically generates SLSA Level 3 provenance in regional builds)
gcloud builds submit \
  --region="${REGION}" \
  --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/prod-containers/payments-api:v1.0.0" .

# 3. Inspect the cryptographic SLSA Provenance & Image Digest
gcloud artifacts docker images describe \
  "${REGION}-docker.pkg.dev/${PROJECT_ID}/prod-containers/payments-api:v1.0.0" \
  --show-provenance

# 4. Verify that GKE Binary Authorization blocks an unverified/unattested container image
kubectl run rogue-container \
  --namespace=payments-prod \
  --image="${REGION}-docker.pkg.dev/${PROJECT_ID}/prod-containers/rogue-image:latest"
```
**Expected Output during Live Demo:**
```text
Error from server (Forbidden): admission webhook "imagepolicywebhook.image-policy.k8s.io" denied the request:
Image us-central1-docker.pkg.dev/.../rogue-image@sha256:... denied by Binary Authorization default admission rule:
No valid attestation found for attestor projects/your-gcp-project-id/attestors/prod-ci-attestor
```

---

## 📋 4. Summary Table: Supply Chain Threat → GCP Control

| Threat / Real-World Incident | Root Vulnerability | CI/CD Fix | Google Cloud / GKE Fix |
| :--- | :--- | :--- | :--- |
| **`tj-actions` / `reviewdog` (CVE-2025-30066)** | Mutable action tags (`@v4`) + runner memory secret dump | Pin all actions to 40-char commit SHAs | Kill JSON keys (`iam.disableServiceAccountKeyCreation`) + short-lived WIF tokens + VPC-SC |
| **Nx (`s1ngularity`) & Loose OIDCHijack** | `pull_request_target` + WIF checking only `repository` | Never checkout untrusted PR code in privileged workflows | Strict WIF **CEL Attribute Condition** (`repository_owner_id`, `ref == 'refs/heads/main'`, `job_workflow_ref`) |
| **`Shai-Hulud 2.0` & `Mini Shai-Hulud` (2025–2026)** | Rogue `SHA1HULUD` self-hosted runners + `pnpm` cache / PR OIDC theft | Audit runners; `permissions: contents: read`; separate PR workflows | Require `assertion.runner_environment == 'github-hosted'` + `ref == 'refs/heads/main'` in WIF CEL |
| **`ChainDrop` Worm (Aug 2026) & `GhostAction`** | `keyv` / 400+ pkgs with Bun `setup.mjs` + Ethereum C2 stealing keys | `--ignore-scripts`; OIDC Trusted Publishing instead of static npm tokens | **Artifact Registry Immutable Tags** + **Cloud Build SLSA L3** + **GKE Binary Authorization** + **VPC-SC** |
| **GKE Pod Compromise / SSRF** | Node default Compute SA (`roles/editor`) exposed via metadata | Drop unnecessary capabilities; network policies | **Workload Identity Federation for GKE** (`PROJECT.svc.id.goog`) with direct per-KSA IAM bindings |
