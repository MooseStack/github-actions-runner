{{/*
Expand the name of the chart.
*/}}
{{- define "arc-openshift.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified name.
*/}}
{{- define "arc-openshift.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "arc-openshift.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: actions-runner-controller
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Controller service account name — reads from controller sub-chart values
*/}}
{{- define "arc-openshift.controllerServiceAccountName" -}}
{{- .Values.controller.serviceAccount.name | default "arc-gha-rs-controller" }}
{{- end }}

{{/*
Runner service account name. Created and used by the runner.
*/}}
{{- define "arc-openshift.runnerServiceAccountName" -}}
{{- .Values.runnerServiceAccountName | default "arc-runner-sa" }}
{{- end }}
