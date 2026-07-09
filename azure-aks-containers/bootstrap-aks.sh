#!/usr/bin/env bash
# AKS lab bootstrap for Azure Cloud Shell — creates ~/aks with the Helm chart.
#
# NOTE ON PASTING: Cloud Shell can drop newlines inside very long heredocs.
# If a file comes out truncated, restore it with a single-line command:
#     echo '<base64>' | base64 -d > path/to/file
# (base64 the correct file locally with:  base64 -w0 file)

mkdir -p ~/aks/app ~/aks/helm/portfolio-app/templates && cd ~/aks

# ---- Dockerfile (kept for reference; only usable where ACR Tasks is enabled) ----
cat > app/Dockerfile <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF

cat > helm/portfolio-app/Chart.yaml <<'EOF'
apiVersion: v2
name: portfolio-app
description: A minimal Helm chart deploying a containerized app to AKS.
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

cat > helm/portfolio-app/values.yaml <<'EOF'
replicaCount: 2
image:
  repository: REPLACE_ME.azurecr.io/portfolio-app
  tag: "v1"
  pullPolicy: IfNotPresent
service:
  type: LoadBalancer
  port: 80
  targetPort: 80
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
probes:
  enabled: true
EOF

# ---- ConfigMap: app content lives OUTSIDE the image ----
cat > helm/portfolio-app/templates/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-web
  labels:
    app: {{ .Release.Name }}
data:
  index.html: |
    <!DOCTYPE html><html><head><meta charset="utf-8"/><title>Running on AKS</title>
    <style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b0f17;color:#e6edf6;font-family:sans-serif}
    .card{text-align:center;padding:48px 56px;border:1px solid #1f2937;border-radius:16px;background:#131a27}
    h1{margin:0 0 10px}p{margin:0;color:#9aa7b8}
    .meta{margin-top:22px;font-family:monospace;font-size:.82rem;color:#38bdf8}
    .dot{display:inline-block;width:9px;height:9px;border-radius:50%;background:#34d399;margin-right:8px}</style>
    </head><body><div class="card">
    <h1><span class="dot"></span>Running on Azure Kubernetes Service</h1>
    <p>Image pulled from private ACR &middot; Deployed with Helm &middot; No passwords</p>
    <p class="meta">release: {{ .Release.Name }} &middot; replicas: {{ .Values.replicaCount }}</p>
    </div></body></html>
EOF

cat > helm/portfolio-app/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: web
              mountPath: /usr/share/nginx/html
              readOnly: true
          {{- if .Values.probes.enabled }}
          livenessProbe:
            httpGet:
              path: /
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 2
            periodSeconds: 5
          {{- end }}
      volumes:
        - name: web
          configMap:
            name: {{ .Release.Name }}-web
EOF

cat > helm/portfolio-app/templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - protocol: TCP
      port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort }}
EOF

echo "=== AKS lab files created in ~/aks ==="
find . -type f | sort
