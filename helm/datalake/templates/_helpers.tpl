{{/*
Expand the name of the chart.
*/}}
{{- define "datalake.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "datalake.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "datalake.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "datalake.labels" -}}
helm.sh/chart: {{ include "datalake.chart" . }}
{{ include "datalake.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app: {{ .Values.global.labels.app }}
environment: {{ .Values.global.labels.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "datalake.selectorLabels" -}}
app.kubernetes.io/name: {{ include "datalake.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "datalake.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "datalake.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MinIO labels
*/}}
{{- define "datalake.minio.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
PostgreSQL labels
*/}}
{{- define "datalake.postgres.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: postgres
{{- end }}

{{/*
Trino labels
*/}}
{{- define "datalake.trino.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: trino
{{- end }}

{{/*
Spark Master labels
*/}}
{{- define "datalake.spark-master.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: spark-master
{{- end }}

{{/*
Spark Worker labels
*/}}
{{- define "datalake.spark-worker.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: spark-worker
{{- end }}

{{/*
Airflow labels
*/}}
{{- define "datalake.airflow.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: airflow
{{- end }}

{{/*
Hive Metastore labels
*/}}
{{- define "datalake.hive-metastore.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: hive-metastore
{{- end }}

{{/*
Marquez labels
*/}}
{{- define "datalake.marquez.labels" -}}
{{ include "datalake.labels" . }}
app.kubernetes.io/component: marquez
{{- end }}
