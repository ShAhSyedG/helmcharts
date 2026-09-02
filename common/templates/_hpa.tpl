{{- define "common.hpas" -}}
{{- $root := . -}}
{{- $namespace := include "common.namespace" $root -}}
{{- range $key := (include "common.selectedServices" $root | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $root "key" $key) | fromYaml }}
{{- $autoscaling := default (dict) $svc.autoscaling }}
{{- if and $autoscaling.enabled $svc.image }}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ printf "%s-hpa" (include "common.name" (dict "root" $root "key" $key)) | trunc 63 | trimSuffix "-" }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.labels" (dict "root" $root "key" $key) | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "common.name" (dict "root" $root "key" $key) }}
  minReplicas: {{ default 1 $autoscaling.minReplicas }}
  maxReplicas: {{ default 4 $autoscaling.maxReplicas }}
  metrics:
    {{- with $autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
    {{- with $autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ . }}
    {{- end }}
  {{- with $autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
{{- end -}}
