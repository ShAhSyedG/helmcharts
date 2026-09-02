{{/*
AWS Load Balancer Controller TargetGroupBindings, attached to the service that
owns them so a target group can never outlive the service it points at.
*/}}
{{- define "common.targetGroupBindings" -}}
{{- $root := . -}}
{{- $namespace := include "common.namespace" $root -}}
{{- range $key := (include "common.selectedServices" $root | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $root "key" $key) | fromYaml }}
{{- $service := default (dict) $svc.service }}
{{- $serviceName := default (include "common.name" (dict "root" $root "key" $key)) $service.name }}
{{- range $tgb := default (list) $svc.targetGroupBindings }}
---
apiVersion: elbv2.k8s.aws/v1beta1
kind: TargetGroupBinding
metadata:
  name: {{ $tgb.name }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.labels" (dict "root" $root "key" $key) | nindent 4 }}
spec:
  serviceRef:
    name: {{ default $serviceName $tgb.serviceName }}
    port: {{ $tgb.port }}
  targetGroupARN: {{ required (printf "services.%s.targetGroupBindings[].targetGroupARN is required" $key) $tgb.targetGroupARN }}
{{- end }}
{{- end }}
{{- end -}}
