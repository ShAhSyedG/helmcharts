# PracticeInvesting

Helm chart for the **PracticeInvesting** stack. All rendering logic comes from the shared
[`common`](../common) library chart; this chart carries values only.

## Environments

| StackValues | Namespace | Services | Overlays |
|---|---|---|---|
| `devpt-values` | `dev-pt` | 7 | 7 |
| `production-values` | `prod-pt` | 9 | 9 |
| `qapt-values` | `qa-pt` | 8 | 8 |

## Deploy the whole stack

```bash
make deps
helm upgrade --install <release> ./PracticeInvesting \
  --namespace <namespace> \
  -f PracticeInvesting/StackValues/<env>-values.yaml
```

The StackValues file is the complete, authoritative definition of that
environment: namespace, registry, pull secrets, and every service.

## Deploy one service

```bash
helm upgrade --install <release> ./PracticeInvesting \
  --namespace <namespace> \
  -f PracticeInvesting/StackValues/<env>-values.yaml \
  -f PracticeInvesting/ServiceValues/<env>/<service>.yaml \
  --set services.<service>.image.tag=$IMAGE_TAG
```

A ServiceValues file is a thin overlay, never a standalone release. It carries
the image tag and a `serviceSelection.include` naming its one service;
everything else comes from the StackValues file passed before it. Using one on
its own is refused with an explanatory error.

## Changing configuration

Edit the environment's StackValues file. Adding a service means adding one key
to its `services` map — the workload, its Service, its autoscaling and its
ingress are all described there together.

The schema is documented in [values.yaml](values.yaml), and the full contract,
including the `compatibility.render` gates for the fields the previous templates
silently dropped, is in [docs/values-contract.md](../docs/values-contract.md).
