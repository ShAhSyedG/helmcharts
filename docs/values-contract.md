# StackValues and ServiceValues

Every chart in this repository is driven by two kinds of values file. They are
not interchangeable, and they are not two ways of doing the same thing.

| | **StackValues** | **ServiceValues** |
|---|---|---|
| Path | `<Chart>/StackValues/<env>-values.yaml` | `<Chart>/ServiceValues/<env>/<service>.yaml` |
| Scope | One environment, every service in it | One service, in one environment |
| Content | Complete and authoritative | Only the delta, usually the image tag |
| Used alone | Yes | **No** — always layered on its StackValues file |
| Answers | "What does qa consist of?" | "Ship this one service to qa." |

## StackValues — the definition of an environment

A StackValues file is the single source of truth for what an environment
contains: its namespace, its registry and pull secrets, its ingress defaults,
and the full `services` map. It is complete on its own, so it is what you use to
stand up a new environment, to rebuild one, or to review what is deployed.

```bash
helm upgrade --install practice-qa ./PracticeInvesting \
  --namespace qa-pt \
  -f PracticeInvesting/StackValues/qapt-values.yaml
```

Everything in the release is described by that one file. Adding a service to an
environment means adding a key to its `services` map — nowhere else.

## ServiceValues — one service out of that environment

A ServiceValues overlay exists for the routine case: CI has built one service
and wants to ship only that one, without touching its neighbours. It carries the
delta and nothing else.

```yaml
# PracticeInvesting/ServiceValues/qapt/tradeservice.yaml
serviceSelection:
  include:
    - trade-rest

services:
  trade-rest:
    image:
      tag: 'qa'
```

It is always passed **after** its StackValues file:

```bash
helm upgrade --install practice-qa-trade ./PracticeInvesting \
  --namespace qa-pt \
  -f PracticeInvesting/StackValues/qapt-values.yaml \
  -f PracticeInvesting/ServiceValues/qapt/tradeservice.yaml \
  --set services.trade-rest.image.tag=$IMAGE_TAG
```

The stack file supplies the image repository, ports, environment variables,
resources and Service definition; the overlay supplies the tag and narrows the
release to that one service.

### Why `serviceSelection` exists

Helm merges values maps, so a later `-f` can add to or overwrite `services`, but
it can never *remove* the other entries. An overlay therefore cannot narrow a
release by redefining `services` — it would still render all of them.

That is precisely why the old `ServiceValues/` files were full copies of the
stack entry rather than overlays, and why they drifted: `devpt/gateway.yaml`
carried `namespace: production`, so deploying the dev gateway would have created
it in the production namespace.

`serviceSelection.include` solves it directly. The templates render only the
listed services, so the overlay stays three lines long and the definition lives
in exactly one place.

```yaml
serviceSelection:
  include: []   # empty: render every service (what StackValues do)
  exclude: []   # subtract from the above, for a targeted rollback
```

### The guard

An overlay used without its stack file is the obvious mistake, and the charts
refuse it rather than deploying something half-defined:

```
$ helm template rel PracticeInvesting -f PracticeInvesting/ServiceValues/qapt/tradeservice.yaml

serviceSelection.include names "trade-rest", but the loaded values do not
define that service.

A ServiceValues overlay only carries the delta for one service, so it must be
layered on top of the StackValues file for the same environment:
  ...
```

Passing no values at all is refused the same way. An empty `services` map would
otherwise render an empty release, and `helm upgrade` would delete every object
the release owns.

## The service entry

One key under `services` describes a service completely — workload, Service,
autoscaling, ingress and load-balancer bindings together. The previous layout
kept `deployment:`, `services:` and `targetGroupBindings:` as parallel maps that
had to be edited in step, and they drifted: `qapt-values.yaml` defined a Service
named `tradeexecutionreportservice` with no matching deployment, so it selected
no pods.

```yaml
services:
  gateway:
    enabled: true
    image:
      repository: tappeng/onboarding_gateway_pt
      tag: qa
    replicas: 1
    env: []
    ports:
      - containerPort: 80
    service:
      name: gatewayservice     # defaults to the key
      ports:
        - {name: http, port: 80, targetPort: 80, protocol: TCP}
    autoscaling:
      enabled: true
      minReplicas: 1
      maxReplicas: 4
      targetCPUUtilizationPercentage: 80
    ingress:
      enabled: false
    targetGroupBindings: []
```

Two shapes fall out of this naturally:

- **Workload with no Service** — omit `service`, or set `service.enabled: false`.
- **Service with no workload** — omit `image`. No Deployment or HPA is rendered.
  `robo-lb-e` in `RoboAdvisory/StackValues/qa-values.yaml` is the one case that
  also sets an explicit `service.selector`, because it fronts another key's pods.

Chart-wide defaults live in each chart's `values.yaml` under `defaults:` and are
merged underneath every entry, so a chart's Service type and pull policy are
stated once.

> Note on booleans: Helm's `mergeOverwrite` is backed by mergo, which treats
> `false` as unset and will not let it override a default of `true`. The
> `enabled` flags are therefore re-applied explicitly after the merge, in
> `common.service.config`. Follow that pattern if you add another flag.

## compatibility.render

Four fields were accepted in values but silently dropped by the old templates:
`resources`, `readinessProbe`/`livenessProbe`, `command` and
`serviceAccountName`. Hundreds of lines of configuration have never reached a
cluster.

The refactored templates can render all four, but they are **off by default** so
that adopting these charts changes nothing on the first apply:

```yaml
compatibility:
  render:
    resources: false
    probes: false
    command: false
    serviceAccountName: false
```

Turn them on one field and one environment at a time, lowest environment first,
and check what changes before you apply it:

```bash
helm template rel ./RoboAdvisory -f RoboAdvisory/StackValues/dev-values.yaml \
  --set compatibility.render.resources=true | less
```

Each carries a distinct risk, and none of them should be enabled everywhere at
once:

- **`resources`** — pods become Guaranteed/Burstable and can be evicted,
  throttled, or left Pending if the declared requests do not fit the nodes.
- **`probes`** — every declared probe targets `/health/ok`. If a service does
  not serve that path, enabling liveness probes puts it in CrashLoopBackOff.
  Enable `readinessProbe` first and confirm endpoints stay ready.
- **`command`** — the declared commands have never run, and some cannot work as
  written: `["java", "-jar", "/opt/app/*.jar"]` has no shell to expand that
  glob, and `RoboAdvisory` `investor` spells the key `commnad`. Check each one
  against its image's `ENTRYPOINT` before enabling.
- **`serviceAccountName`** — `PracticeInvesting` `gateway` asks for `dev-sa` in
  every environment, production included. The pod will not start if that
  ServiceAccount is absent.
