# services-documentdb

Two nullplatform dependency services backed by **Amazon DocumentDB**, shipped as
worker images on the packaged (OCI) model.

| Service | Creates AWS infrastructure? | What it does |
|---|---|---|
| `documentdb-cluster` | **Yes** — cluster, instances, subnet group, cluster parameter group, security group, master secret | Each link creates its own MongoDB user, scoped to a database the link names |
| `documentdb-database` | **No** | Finds a `documentdb-cluster` in the same namespace and creates one database inside it. Each link adds a user scoped to that database |

The split mirrors `nullplatform/services-rds` (`rds-postgres-server` /
`rds-postgres-db`): one service owns the expensive, slow, shared resource; the
other hands out cheap, fast, per-application slices of it.

---

## Read this before planning a test

**DocumentDB has no public endpoint. It never has one.** It is VPC-only by
design — there is no `publicly_accessible` equivalent as there is on RDS. From
outside the VPC it is reachable only through an SSH tunnel, VPC peering or VPN.

That splits testing cleanly in two:

| Action | Works with an agent on your laptop? | Why |
|---|---|---|
| `create` / `update` / `delete` of the cluster | **Yes** | Pure control plane: tofu talks to the AWS API, never to the cluster |
| `link` / `link-update` / `unlink` | **No** | `mongo_user.sh` opens port 27017 against the cluster itself |
| Anything on `documentdb-database` | **No** | Its only job is talking to the cluster |

Making links work needs **an agent inside the VPC** — EKS, EC2, ECS, it does not
matter which. The requirement is network reach to 27017, not Kubernetes.

Packaging does not change this. The worker runs wherever the agent runs.

---

## Repository layout

```
.
├── Dockerfile.cluster              # worker image for documentdb-cluster
├── Dockerfile.database             # worker image for documentdb-database
├── documentdb-cluster/
│   ├── specs/
│   │   ├── service-spec.json.tpl   # what the developer sees when creating the service
│   │   ├── links/connect.json.tpl  # what they see when linking an application
│   │   └── requirements/aws/       # the IAM role the agent assumes (applied by the installer)
│   ├── deployment/                 # the cluster itself
│   ├── permissions/                # one MongoDB user per link (+ mongo_user.js)
│   ├── scripts/aws/                # build_context, do_tofu, write_*_outputs
│   ├── utils/                      # assume-role resolution
│   ├── entrypoint/                 # action → workflow dispatch
│   ├── workflows/aws/              # create, update, delete, link, link-update, unlink
│   └── values.yaml                 # static config, not exposed in the UI
├── documentdb-database/            # same shape; db_setup/ replaces deployment/
├── examples/registration/          # ready-to-copy terraform for whoever installs this
└── test/                           # runs the MongoDB logic against a real mongod
```

### Two propagation paths — the thing that bites

**`specs/` is read from the repository over HTTPS on every `tofu apply`.** Change
a schema, a uiSchema, a selector or a link and an apply is enough.

**Everything else is baked into the image** — `scripts/`, `workflows/`,
`deployment/`, `permissions/`, `db_setup/`, `values.yaml`. Change any of those
and you need: rebuild → new digest → bump `package.version` → apply.

Editing a script and only running `apply` does nothing at all. The worker keeps
executing what is inside the image. This is the easiest mistake to make here and
the most confusing to diagnose, because nothing fails.

Existing service instances never move: each is bound for life to the package
revision it was born with, so a new version only applies to instances created
after it.

---

## What is verified, and what is not

Being explicit, because "it validates" and "it works" are very different claims.

**Verified on a real machine:**

- `tofu validate` on all five modules, plus both registration layers
- `tofu fmt` clean
- Both images build, and carry `bash`, `jq`, `np`, `aws`, `tofu`, `mongosh`, `gomplate`
- `shellcheck --severity=error` clean across all 29 shell scripts (the level CI runs)
- **The MongoDB provisioning logic, against a real mongod**: 12 assertions
  covering every access level, the custom write role, idempotent re-apply, level
  changes, role reclamation, and database materialisation. Run it with
  `./test/run.sh`

**Not verified, and worth knowing:**

- **Nothing has been applied to AWS.** No cluster has ever been created by this
  code. The terraform is checked for syntax and types, not for AWS semantics.
- **Nothing has run against DocumentDB itself.** The tests use stock MongoDB, so
  they say nothing about TLS with the RDS CA bundle, the `replicaSet=rs0`
  topology, `retryWrites=false`, or the 100 user-defined-role cap.
- **No slug collision check** was run against a live nullplatform account.

---

## Prerequisites on the AWS side

Registering the services does **not** grant the agent permission to do anything.
Four things are needed and none are automatic:

1. **Apply the requirements modules** — `documentdb-cluster/specs/requirements/aws`
   and `documentdb-database/specs/requirements/aws`. Each creates the IAM role
   the agent assumes.
2. **Publish each `permissions_role_arn`** to the `aws-iam-configuration`
   provider, under the selectors **`documentdb-cluster`** and
   **`documentdb-database`** — those are the values `utils/assume_role_step`
   looks up.
3. **Confirm the account providers exist**: `aws-configuration` (exposing
   `account.region`) and `aws-networking-configuration` (exposing `vpc.id`).
   `build_context` resolves both and fails loudly if either is missing.
4. **Tag the private subnets** `nullplatform/subnet-type = private`. The subnet
   group is built from that tag, and an untagged VPC produces an empty subnet
   list rather than an error.

---

## Releasing

`.github/workflows/release.yml` cuts a release with release-please, builds both
images multi-arch, pushes them to the private ECR at `235494813897.dkr.ecr.us-east-1.amazonaws.com`,
and writes the two digests into the release body.

It is a **local workflow, not the shared
`actions-nullplatform/release-publish-oci.yml`**. That one logs in with
`registry-type: public` — hardcoded in every version, including `main` — so it
can only reach ECR Public. A private registry needs its own login, which is the
single line this file exists for. The rest deliberately mirrors the shared
pipeline: one chained run, because release-please tags with `GITHUB_TOKEN` and
GitHub never triggers workflows from bot-token events.

Configure one secret:

| Kind | Name | What it is |
|---|---|---|
| secret | `AWS_ROLE_ARN_ECR_PUSH` | Role assumed via OIDC, with `ecr:*` on the two repositories |

Nothing else. The artifact is registered by **terraform**, from the `package`
block's `meta`, so no nullplatform key and no artifact NRN are needed in CI.

The role needs a trust policy for this repository through the account's GitHub
OIDC provider — the permission policy alone is not enough, and a missing trust
policy fails at the very first step with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`, before ECR is ever
touched.

Both ECR repositories must already exist — `service-documentdb-cluster` and
`service-documentdb-database`. ECR never creates one on push, and the two
failure messages differ: a 403 means the role's policy does not cover that
repository, while "repository does not exist" means the name is wrong or the
repository is genuinely absent.

### Building locally

```bash
# Native build. Do NOT pass --platform linux/amd64 under the legacy builder on
# an arm64 machine — it fails at COPY.
docker build -f Dockerfile.cluster -t documentdb-cluster:dev .
```

Without buildx, `TARGETARCH` is not populated and the tofu download 404s. Pass
it explicitly: `--build-arg TARGETARCH=arm64`. A local build is for inspection
only: it produces a single-architecture image, and the agent's nodes are usually
amd64. CI builds both architectures.

## Registering

The terraform belongs in the infrastructure repo of whoever installs the
service, not here. `examples/registration/` has both layers ready to copy, with
the module arguments already pinned to `tofu-modules` v7.11.0.

```bash
cp examples/registration/common.tfvars.example common.tfvars   # then fill it in
export TF_VAR_np_api_key="<key>"

cd examples/registration/nullplatform            && tofu init && tofu apply -var-file=../common.tfvars
cd ../nullplatform-bindings                      && tofu init && tofu apply -var-file=../common.tfvars
```

Order matters: the bindings layer reads the registered spec slugs out of the
first layer's state.

Three arguments that look redundant and are not:

- **`repository_branch` must be a tag.** The module rejects a branch name.
- **`repository_token`** is required while this repository is private. The
  module fetches the spec files over HTTPS on every apply, so a private repo
  without a fine-grained `Contents: Read-only` token fails at plan time.
- **`entrypoint`** must be passed explicitly. The module defaults to
  `/app/packages/<slug>/entrypoint`; the Dockerfiles bake
  `/app/pkg/<slug>/entrypoint/entrypoint`. They do not match, the apply succeeds
  anyway, and the first action fails on a path that is not in the image.

Finally, wire the worker on the agent — the worker does **not** inherit the
agent's environment:

```hcl
worker_orchestrated_packages = ["containers", "documentdb-cluster", "documentdb-database"]
```

`allowedRegistries` needs setting. The agent module defaults to
`["public.ecr.aws/nullplatform/*"]`, which does not cover this private ECR.
Entries set here are **concatenated** with that default rather than replacing
it, so add only this one:

```hcl
worker = { allowedRegistries = ["235494813897.dkr.ecr.us-east-1.amazonaws.com/*"] }
```

A private registry also needs the worker pods to be able to *pull* from it:
`ecr:GetAuthorizationToken` and `ecr:BatchGetImage` on the node role, IRSA or an
imagePullSecret, depending on the cluster. Without it the pod sits in
`ImagePullBackOff` and the service action dies on a timeout that says nothing
about permissions.

---

## Testing

```bash
./test/run.sh
```

Starts a MongoDB container, builds the cluster image if needed, and runs the
provisioning logic inside the real worker image. Twelve assertions, no AWS
credentials, no nullplatform account.

It covers the part with the most behaviour per line and the least type safety.
It does not cover DocumentDB — see "What is verified" above.

---

## Design decisions worth preserving

Each of these looks like something to clean up, and each is load-bearing.

**The master password is not a Terraform variable, and cannot be.** A
destroy-time provisioner may reference `self` and nothing else. So the secret's
ARN travels in `triggers`, and `mongo_user.sh` re-reads Secrets Manager on every
run — including unlink. That is also why the IAM policy needs
`secretsmanager:GetSecretValue` and not just write access.

**A workflow step's `output:` block is a security boundary, not plumbing.**
`build_context` exports `TOFU_MODULE_DIR` pointing at the deployment module. The
link workflows deliberately do not declare it. If they did, and
`build_permissions_context` exited early, the following `tofu destroy` would
inherit the deployment module and take the entire cluster with it — on an
unlink. Undeclared, `do_tofu` dies on an unbound variable under `set -u`, which
is the intended behaviour.

The same mechanism runs the other way in `documentdb-database`:
`write_service_outputs` there reads the cluster details out of the environment
rather than from tofu, so every one of those variables **must** be declared, or
the service registers without knowing which cluster it lives in.

**`delete.yaml` declares `TFSTATE_BUCKET`.** Without it `delete_tfstate_bucket`
sees an empty variable, prints "skipping" and exits 0, orphaning one bucket per
deletion.

**`write` costs a user-defined role, and there are only 100.** MongoDB has no
write-only built-in: `readWrite` always implies `find`. So `write` is
implemented with a real `db.createRole`, and DocumentDB caps user-defined roles
at 100 per cluster. `read` and `read-write` use built-ins and consume none.

**`retryWrites=false` is mandatory.** DocumentDB does not implement retryable
writes and every modern driver defaults them on. It is already in the exported
connection string.

**The security group opens to every CIDR associated with the VPC**, not just the
primary. EKS clusters commonly add a secondary CIDR for pod networking, and pods
draw their IPs from it. Restricting to the primary blocks the agent silently —
every link then hangs until mongosh times out.

**Names are frozen after the first create.** `cluster_identifier` is ForceNew,
so `build_context` reads it back from the service attributes rather than
recomputing it from the service name. Without that, renaming a service would
destroy the cluster and build an empty replacement, as an ordinary update. The
database service freezes `database_name` and `resolved_cluster_service_id` for
the same reason.

**mongosh is installed from npm with a pinned transitive dependency.** There is
no mongosh in Alpine and MongoDB ships only glibc builds, so npm is the only
form that runs on this musl base. The `@mongodb-js/oidc-plugin` override is
equally forced: its 2.x line needs Node ≥ 20.19.2 and is ESM-only, while the
base image has 20.15.1. Pinning only the mongosh version does not hold, because
`npm install -g` re-resolves transitives on every build.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| Notification `success` but nothing happened | `success` only means dispatch to the agent worked. The real exit code is at `/notification/<id>/result` |
| Notification delivered, never executes | Tag mismatch. Compare `tags_selectors` against the agent's `-tags` flag |
| First action fails on a missing path | The channel `entrypoint` was left at the module default. See "Registering" |
| A script change had no effect | It is baked in the image. Rebuild, bump `package.version`, apply |
| Link hangs, then times out | No network reach to 27017. This is the VPC constraint, not a bug |
| `KMSKeyNotAccessibleFault` on create | The requirements module was not applied — `kms:CreateGrant` / `kms:DescribeKey` live there |
| Auto-discovery fails with "N clusters active" | Set `cluster_service_id` on the database service to choose deliberately |
| An IAM policy "applies" but grants nothing | Check the prefix. DocumentDB has no IAM namespace — every action is `rds:*`, never `docdb:*` |
