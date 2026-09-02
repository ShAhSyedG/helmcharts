{{/*
Guards that turn the StackValues / ServiceValues contract into something the
chart enforces, rather than a convention people have to remember.

  StackValues/<env>-values.yaml   complete definition of one environment
  ServiceValues/<env>/<svc>.yaml  thin overlay for ONE service in that environment

An overlay is always layered on top of its stack file:

  helm upgrade --install <rel> ./<Chart> -n <ns> \
    -f <Chart>/StackValues/<env>-values.yaml \
    -f <Chart>/ServiceValues/<env>/<svc>.yaml

Helm merges maps, so an overlay can never remove the other services from
`services`; it narrows the release with serviceSelection.include instead. If the
overlay is passed on its own, the name it selects is missing from `services` and
the first check below fails with an actionable message instead of rendering an
empty or half-defined release.
*/}}
{{- define "common.validate" -}}
{{- $selection := default (dict) .Values.serviceSelection -}}
{{- $include := default (list) $selection.include -}}

{{- /* Keys the loaded values define completely, as opposed to keys an overlay
       merely mentions. Used to make the error below actionable. */ -}}
{{- $defined := list -}}
{{- range $k, $v := .Values.services -}}
{{- $img := default (dict) $v.image -}}
{{- $sb := default (dict) $v.service -}}
{{- if or $img.repository (gt (len (default (list) $sb.ports)) 0) -}}
{{- $defined = append $defined $k -}}
{{- end -}}
{{- end -}}

{{- range $name := $include }}
{{- $entry := default (dict) (get $.Values.services $name) }}
{{- $image := default (dict) $entry.image }}
{{- $svcBlock := default (dict) $entry.service }}
{{- /* A stack file always defines a service completely: it has an image
       repository, or it is a Service-only entry with ports. An overlay on its
       own has neither — it carries just an image tag. */}}
{{- if not (has $name $defined) }}
{{- fail (printf "\n\nserviceSelection.include names %q, but the loaded values do not define that service.\n\nA ServiceValues overlay only carries the delta for one service, so it must be layered on top of the StackValues file for the same environment:\n\n  helm upgrade --install <release> ./%s -n <namespace> \\\n    -f %s/StackValues/<env>-values.yaml \\\n    -f %s/ServiceValues/<env>/%s.yaml\n\nServices fully defined by the values currently loaded: %v\n" $name $.Chart.Name $.Chart.Name $.Chart.Name $name (sortAlpha $defined)) }}
{{- end }}
{{- end }}

{{- if and (empty $.Values.services) (empty $include) }}
{{- fail (printf "\n\nNo services are defined for this release.\n\nPass the StackValues file for the environment you are deploying:\n\n  helm upgrade --install <release> ./%s -n <namespace> -f %s/StackValues/<env>-values.yaml\n" $.Chart.Name $.Chart.Name) }}
{{- end }}

{{- range $key := (include "common.selectedServices" . | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $ "key" $key) | fromYaml }}
{{- if and $svc.autoscaling $svc.autoscaling.enabled }}
{{- if lt (int $svc.autoscaling.maxReplicas) (int $svc.autoscaling.minReplicas) }}
{{- fail (printf "services.%s.autoscaling: maxReplicas (%v) is below minReplicas (%v)" $key $svc.autoscaling.maxReplicas $svc.autoscaling.minReplicas) }}
{{- end }}
{{- end }}
{{- if and $svc.service $svc.service.externalTrafficPolicy }}
{{- $type := default "ClusterIP" $svc.service.type }}
{{- if not (has $type (list "NodePort" "LoadBalancer")) }}
{{- fail (printf "services.%s.service: externalTrafficPolicy is only valid for NodePort and LoadBalancer services, but type is %s" $key $type) }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
