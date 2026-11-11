{{/*
Resources keep fixed names (api, postgres) rather than a release-prefixed one.
The namespace already isolates this deployment, DB_HOST stays a stable
"postgres", and the StatefulSet keeps claiming the same PVC (data-postgres-0)
across reinstalls instead of orphaning the data.
*/}}

{{/* Labels applied to every object. */}}
{{- define "shop.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels. A workload's selector is immutable, so this stays minimal:
anything that changes between releases (chart version, app version) must not
appear here. Call as: include "shop.selectorLabels" (dict "ctx" . "component" "api")
*/}}
{{- define "shop.selectorLabels" -}}
app.kubernetes.io/name: {{ .ctx.Chart.Name }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/* Image reference; tag falls back to the chart's appVersion. */}}
{{- define "shop.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/* DB_USER and DB_PASSWORD, read from the externally created Secret. */}}
{{- define "shop.dbCredentialEnv" -}}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: DB_USER
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.existingSecret }}
      key: DB_PASSWORD
{{- end }}

{{/* Pod-level hardening shared by every workload. */}}
{{- define "shop.podSecurityContext" -}}
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/* Container-level hardening shared by every workload. */}}
{{- define "shop.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop: ["ALL"]
{{- end }}
