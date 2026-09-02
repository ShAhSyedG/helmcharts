{{- define "common.deployments" -}}
{{- $root := . -}}
{{- $namespace := include "common.namespace" $root -}}
{{- range $key := (include "common.selectedServices" $root | fromYamlArray) }}
{{- $svc := include "common.service.config" (dict "root" $root "key" $key) | fromYaml }}
{{- if $svc.image }}
{{- $render := $root.Values.compatibility.render }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "common.name" (dict "root" $root "key" $key) }}
  namespace: {{ $namespace }}
  labels:
    {{- include "common.labels" (dict "root" $root "key" $key) | nindent 4 }}
  {{- with $svc.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- /* When an HPA owns this Deployment, replicas is left unset so the two do
         not fight over the replica count on every `helm upgrade`. */}}
  {{- if not (and $svc.autoscaling $svc.autoscaling.enabled) }}
  replicas: {{ default 1 $svc.replicas }}
  {{- end }}
  {{- with $svc.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "common.selectorLabels" (dict "root" $root "key" $key) | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "common.labels" (dict "root" $root "key" $key) | nindent 8 }}
        {{- with $svc.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with $svc.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- $pullSecrets := default $root.Values.global.image.pullSecrets $svc.imagePullSecrets }}
      {{- with $pullSecrets }}
      imagePullSecrets:
        {{- range . }}
        - name: {{ . }}
        {{- end }}
      {{- end }}
      {{- if $render.serviceAccountName }}
      {{- with $svc.serviceAccountName }}
      serviceAccountName: {{ . }}
      {{- end }}
      {{- end }}
      {{- with $svc.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $svc.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $svc.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $svc.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $svc.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ $key }}
          image: {{ include "common.image" (dict "root" $root "service" $svc) }}
          imagePullPolicy: {{ default $root.Values.global.image.pullPolicy $svc.imagePullPolicy }}
          {{- if $render.command }}
          {{- with $svc.command }}
          command:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.args }}
          args:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- end }}
          {{- with $svc.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.ports }}
          ports:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if $render.resources }}
          {{- with $svc.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- end }}
          {{- if $render.probes }}
          {{- with $svc.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- end }}
          {{- with $svc.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with $svc.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
{{- end }}
{{- end }}
{{- end -}}
