{{- define "common.ingresses" -}}
{{- $root := . -}}
{{- $namespace := include "common.namespace" $root -}}
{{- $globalIngress := default (dict) $root.Values.global.ingress -}}
{{- range $key := (include "common.selectedServices" $root | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $root "key" $key) | fromYaml }}
{{- $ingress := default (dict) $svc.ingress }}
{{- if $ingress.enabled }}
{{- $certificateArn := default $globalIngress.certificateArn $ingress.certificateArn }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ default (printf "%s-ingress" (include "common.name" (dict "root" $root "key" $key))) $ingress.name }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.labels" (dict "root" $root "key" $key) | nindent 4 }}
  annotations:
    {{- /* Chart-wide ALB defaults first, so a service can override any of them. */}}
    {{- with $globalIngress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $certificateArn }}
    alb.ingress.kubernetes.io/certificate-arn: {{ . }}
    {{- end }}
    {{- with $ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  ingressClassName: {{ default $globalIngress.className $ingress.className }}
  {{- with $ingress.tls }}
  tls:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  rules:
    {{- range $host := $ingress.hosts }}
    - host: {{ $host.host | quote }}
      http:
        paths:
          {{- range $path := $host.paths }}
          - path: {{ $path.path }}
            pathType: {{ default "Prefix" $path.pathType }}
            backend:
              service:
                name: {{ $path.service }}
                port:
                  number: {{ $path.port }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
{{- end -}}
