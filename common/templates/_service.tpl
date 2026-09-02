{{- define "common.services" -}}
{{- $root := . -}}
{{- $namespace := include "common.namespace" $root -}}
{{- range $key := (include "common.selectedServices" $root | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $root "key" $key) | fromYaml }}
{{- $service := default (dict) $svc.service }}
{{- /* `default true $x` returns true when $x is false, so the flag is read
       explicitly here. */}}
{{- $enabled := true }}
{{- if hasKey $service "enabled" }}{{- $enabled = $service.enabled }}{{- end }}
{{- if $enabled }}
{{- $type := default "ClusterIP" $service.type }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ default (include "common.name" (dict "root" $root "key" $key)) $service.name }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.labels" (dict "root" $root "key" $key) | nindent 4 }}
    {{- include "common.legacyServiceLabels" (dict "root" $root "key" $key) | nindent 4 }}
  {{- with $service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $type }}
  {{- /* Only meaningful for NodePort/LoadBalancer; common.validate rejects it
         on a ClusterIP service rather than letting the API server do it. */}}
  {{- with $service.externalTrafficPolicy }}
  externalTrafficPolicy: {{ . }}
  {{- end }}
  {{- with $service.loadBalancerClass }}
  loadBalancerClass: {{ . }}
  {{- end }}
  {{- /* Defaults to the pod label this key's Deployment carries. Override only
         for a Service that fronts a *different* workload. */}}
  selector:
    {{- if $service.selector }}
    {{- toYaml $service.selector | nindent 4 }}
    {{- else }}
    {{- include "common.selectorLabels" (dict "root" $root "key" $key) | nindent 4 }}
    {{- end }}
  {{- with $service.ports }}
  ports:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
