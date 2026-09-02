# WebPortals

Helm chart for the **LiveTradingAdmin** stack. All rendering logic comes from the shared
[`common`](../common) library chart; this chart carries values only.

## Environments

| StackValues | Namespace | Services | Overlays |
|---|---|---|---|
| `dev-values` *(unpopulated)* | `—` | 0 | 0 |
| `production-values` *(unpopulated)* | `—` | 0 | 0 |
| `qa-values` | `web-qa` | 1 | 1 |

## Deploy the whole stack

```bash
make deps
helm upgrade --install <release> ./WebPortals \
  --namespace <namespace> \
  -f WebPortals/StackValues/<env>-values.yaml
```

The StackValues file is the complete, authoritative definition of that
environment: namespace, registry, pull secrets, and every service.

## Deploy one service

```bash
helm upgrade --install <release> ./WebPortals \
  --namespace <namespace> \
  -f WebPortals/StackValues/<env>-values.yaml \
  -f WebPortals/ServiceValues/<env>/<service>.yaml \
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
