{{/*
Single entry point every stack chart includes. Validation runs first so a
misconfigured release fails with an explanatory message before anything renders.
*/}}
{{- define "common.all" -}}
{{- include "common.validate" . -}}
{{- include "common.deployments" . -}}
{{- include "common.services" . -}}
{{- include "common.hpas" . -}}
{{- include "common.ingresses" . -}}
{{- include "common.targetGroupBindings" . -}}
{{- end -}}
