# helmcharts

Helm charts for the four platform stacks. Each chart carries only values; all
rendering logic lives in the shared `common` library chart, so the stacks cannot
drift apart.

```
common/                     library chart — every template lives here
LiveInvest/                 LiveInvesting
PracticeInvesting/          practicetrading
RoboAdvisory/               RoboAdvisory
WebPortals/                 LiveTradingAdmin
docs/values-contract.md     StackValues vs ServiceValues, in full
```

Each stack chart has the same shape:

```
<Chart>/
  Chart.yaml                depends on common
  values.yaml               schema, documentation and chart-wide defaults
  templates/main.yaml       one line: {{ include "common.all" . }}
  StackValues/<env>-values.yaml     one environment, complete
  ServiceValues/<env>/<svc>.yaml    one service, as an overlay
```

## Quick start

```bash
make deps       # resolve the common library chart into each chart
make lint       # helm lint every chart against every StackValues file
make template   # render every chart x environment, and every overlay
```

`make deps` runs `helm dependency update`, which packages `common/` into
`<Chart>/charts/`. It must run **before** any `helm lint`, `helm template` or
`helm upgrade`, including in CI — see [Pipeline changes](#pipeline-changes).

## Deploying

Whole stack:

```bash
helm upgrade --install practice-qa ./PracticeInvesting \
  --namespace qa-pt -f PracticeInvesting/StackValues/qapt-values.yaml
```

One service:

```bash
helm upgrade --install practice-qa-trade ./PracticeInvesting \
  --namespace qa-pt \
  -f PracticeInvesting/StackValues/qapt-values.yaml \
  -f PracticeInvesting/ServiceValues/qapt/tradeservice.yaml \
  --set services.trade-rest.image.tag=$IMAGE_TAG
```

The StackValues file always comes first; the overlay carries only the delta and
narrows the release to its one service. Full rules, including why
`serviceSelection` is needed and what the guard rejects, are in
[docs/values-contract.md](docs/values-contract.md).

## Adding a service

Add one key to the `services` map in the environment's StackValues file, then
add a matching overlay under `ServiceValues/<env>/`. Nothing else changes — no
templates, and no second map to keep in step.

## Pipeline changes

Three things about this layout differ from the previous one. Anything that runs
`helm` against these charts needs to account for them.

1. **`helm dependency update` (or `make deps`) is now required** before lint,
   template, or upgrade. `<Chart>/charts/` and `Chart.lock` are generated and
   gitignored.
2. **`helm lint <Chart>` with no values now fails**, on purpose: an empty
   `services` map would render an empty release, and `helm upgrade` would delete
   every object the release owns. Lint against a StackValues file, or use
   `make lint`.
3. **Two `PracticeInvesting` overlay files were deleted** —
   `ServiceValues/qapt/tenant-management.yaml` and
   `ServiceValues/production/tenant-management.yaml`. Neither environment
   defines a `tenantmanagement` service, so both were dead.

## What this refactor changed in the cluster

Rendered output was diffed object-by-object against the previous templates for
all 13 environments. The object inventory is unchanged except for two fixes, and
`compatibility.render` keeps the previously-dropped fields off, so a first apply
is close to a no-op.

**Cross-environment leaks, now fixed.** Two templates were static files with
namespaces baked in, so *every* environment rendered them into one namespace and
the releases fought over the same object:

- `PracticeInvesting/templates/ingress.yaml` created `prod-pt/ingressgateway` —
  pointing at a production hostname with a production certificate — from the dev
  and qa releases too. It is now defined in `production-values.yaml` only.
- `RoboAdvisory/templates/robo-lb.yaml` created the `qa-robo/robo-lb-e` load
  balancer from all five environments. It is now in `qa-values.yaml` only.

Applying this will remove those objects from the four releases that should never
have owned them. The qa/production releases that legitimately own them keep
them.

**Deliberate changes to rendered manifests.**

- `replicas` is no longer set on a Deployment that has an HPA, so the two stop
  fighting over the replica count on every upgrade (66 Deployments).
- HPA `maxReplicas` now honours the per-service `hpa` block that the old
  template ignored in favour of a hardcoded 1–4. This lowers `maxReplicas` from
  4 to 2 on 23 `LiveInvest` Deployments, which is what those values ask for.
  **Confirm that is the intended ceiling before applying to production.**
- `imagePullSecrets` rendered as `- name:` with an empty value wherever
  `global.app.imagePullSecrets` was unset — invalid, and never a working pull
  secret. Nine Deployments now get the `docker-secret` their own values
  declared, and six in `PracticeInvesting` dev/qa render no pull secret at all,
  because none is configured anywhere. **Those six need a pull secret if their
  images are private.**
- Standard `app.kubernetes.io/*` and `helm.sh/chart` labels are added.
  `meta.helm.sh/release-name` and `meta.helm.sh/release-namespace` are removed
  from labels: those keys are reserved by Helm as *annotations*, and using them
  as labels misleads tooling. The non-standard `app` and `version` labels on
  Services are kept, in case anything selects on them.

**Deliberately not changed.** Object names are still the bare service key, with
no release prefix. A Deployment's `spec.selector` is immutable and renaming a
workload forces a delete and recreate, so this stays as it is;
`global.naming.prefixWithRelease` opts in for a brand new namespace. Service
selectors likewise stay `run: <key>`. Several values declared
`selector: {app: <name>}`, which no pod carries — the old templates ignored it,
and honouring it now would have selected zero pods and dropped traffic, so those
dead selectors were removed rather than applied.

## Known issues not addressed here

These are pre-existing and need a decision from whoever owns the platform:

- `WebPortals/StackValues/dev-values.yaml` and `production-values.yaml` are
  empty. They failed with a nil-pointer error before and fail with an
  explanatory message now, but they are still not deployable.
- `PracticeInvesting` dev and qa declared `IngressRoute` blocks that no template
  ever read, so those environments have no ingress. They are carried over as
  `ingress.enabled: false` rather than being switched on silently.
- Service names and keys are inconsistent across environments
  (`financialpanning` vs `financialplanning`, `robobiling` vs `robobillservice`,
  `trade-rest` vs `tradeservice`). Renaming them is a delete-and-recreate, so
  the typos are preserved exactly.
- AWS account IDs, certificate ARNs, target group ARNs and subnet IDs are
  committed in values. They are identifiers rather than credentials, but they do
  disclose account topology.
- `PracticeInvesting` and `RoboAdvisory` expose internal gRPC services as
  `NodePort`. `ClusterIP` is enough for in-cluster traffic; the type is
  preserved here because changing it releases the node ports.
