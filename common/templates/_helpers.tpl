{{/*
Namespace every object is rendered into.

Prefer `helm ... --namespace <ns>`; global.app.namespace stays supported because
the existing StackValues files set it and the pipelines rely on it.
*/}}
{{- define "common.namespace" -}}
{{- default .Release.Namespace .Values.global.app.namespace -}}
{{- end -}}

{{/*
Chart name and version, as used by the helm.sh/chart label.
*/}}
{{- define "common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Object name for a service.

Names are deliberately NOT prefixed with the release name. Deployments, Services
and HPAs already exist in every cluster under the bare key, and renaming them
would force a delete/recreate. Set global.naming.prefixWithRelease=true only when
bootstrapping a brand new namespace.

Usage: include "common.name" (dict "root" $ "key" $key)
*/}}
{{- define "common.name" -}}
{{- $root := .root -}}
{{- if $root.Values.global.naming.prefixWithRelease -}}
{{- printf "%s-%s" $root.Release.Name .key | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .key | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Selector labels. These land in Deployment.spec.selector, which Kubernetes treats
as immutable, so `run` must stay exactly as it is for existing workloads.

Usage: include "common.selectorLabels" (dict "root" $ "key" $key)
*/}}
{{- define "common.selectorLabels" -}}
run: {{ .key }}
{{- end -}}

{{/*
Metadata labels: the immutable selector label plus the standard Kubernetes
recommended labels. Safe to extend because object metadata labels are mutable.

Usage: include "common.labels" (dict "root" $ "key" $key)
*/}}
{{- define "common.labels" -}}
{{- $root := .root -}}
{{ include "common.selectorLabels" . }}
app.kubernetes.io/name: {{ .key }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
app.kubernetes.io/managed-by: {{ $root.Release.Service }}
app.kubernetes.io/part-of: {{ $root.Values.global.app.name }}
helm.sh/chart: {{ include "common.chart" $root }}
{{- with $root.Values.global.app.version }}
app.kubernetes.io/version: {{ . | quote }}
{{- end }}
{{- end -}}

{{/*
Merge a service definition over the chart-wide `defaults` block, so every stack
chart keeps its own conventions (service type, pull policy, probes) without
repeating them per service.

Usage: include "common.service.config" (dict "root" $ "key" $key) | fromYaml
*/}}
{{- define "common.service.config" -}}
{{- $root := .root -}}
{{- $defaults := deepCopy (default (dict) $root.Values.defaults) -}}
{{- $raw := deepCopy (get $root.Values.services .key) -}}
{{- $merged := mergeOverwrite $defaults $raw -}}
{{- /* mergeOverwrite is backed by mergo, which treats false as "unset" and so
       will not let an explicit `enabled: false` override a default of true.
       Re-apply the flags the service sets for itself. */ -}}
{{- range $section := list "service" "autoscaling" "ingress" -}}
{{- $rawSection := default (dict) (get $raw $section) -}}
{{- if and (kindIs "map" $rawSection) (hasKey $rawSection "enabled") -}}
{{- $mergedSection := default (dict) (get $merged $section) -}}
{{- $_ := set $mergedSection "enabled" (get $rawSection "enabled") -}}
{{- $_ := set $merged $section $mergedSection -}}
{{- end -}}
{{- end -}}
{{- toYaml $merged -}}
{{- end -}}

{{/*
Fully qualified image reference. global.image.registry is an optional prefix so
a mirror or private registry can be swapped in per environment.

Usage: include "common.image" (dict "root" $ "service" $svc)
*/}}
{{- define "common.image" -}}
{{- $root := .root -}}
{{- $image := .service.image -}}
{{- $registry := default "" $root.Values.global.image.registry -}}
{{- $repository := required "services.<name>.image.repository is required" $image.repository -}}
{{- $tag := required "services.<name>.image.tag is required" $image.tag -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" (trimSuffix "/" $registry) $repository (toString $tag) -}}
{{- else -}}
{{- printf "%s:%s" $repository (toString $tag) -}}
{{- end -}}
{{- end -}}

{{/*
The set of service keys this release should render, after applying
serviceSelection. Returns a YAML list.

Usage: include "common.selectedServices" $ | fromYamlArray
*/}}
{{- define "common.selectedServices" -}}
{{- $root := . -}}
{{- $selection := default (dict) $root.Values.serviceSelection -}}
{{- $include := default (list) $selection.include -}}
{{- $exclude := default (list) $selection.exclude -}}
{{- $selected := list -}}
{{- range $key, $service := $root.Values.services -}}
{{- $wanted := or (empty $include) (has $key $include) -}}
{{- $enabled := true -}}
{{- if hasKey $service "enabled" -}}{{- $enabled = $service.enabled -}}{{- end -}}
{{- if and $wanted (not (has $key $exclude)) $enabled -}}
{{- $selected = append $selected $key -}}
{{- end -}}
{{- end -}}
{{- toYaml (sortAlpha $selected) -}}
{{- end -}}

{{/*
Labels the pre-refactor Service template emitted. They are non-standard and
duplicate app.kubernetes.io/name and /version, but external tooling (metrics
scrapers, selectors in other charts) may match on them, so Services keep them.

Usage: include "common.legacyServiceLabels" (dict "root" $ "key" $key)
*/}}
{{- define "common.legacyServiceLabels" -}}
app: {{ .key }}
{{- with .root.Values.global.app.version }}
version: {{ . | quote }}
{{- end }}
{{- end -}}
