# Local Cluster Deployment Guide

This guide covers deploying the EnginEdge Datalake on local Kubernetes clusters.

## Supported Local Clusters

- **kind** (Kubernetes in Docker)
- **k3d** (k3s in Docker)
- **Docker Desktop** (with Kubernetes enabled)
- **Minikube**

## Prerequisites

1. **Kubernetes Cluster**: One of the supported local clusters running
2. **Helm 3**: Installed and configured
3. **kubectl**: Installed and configured to access your cluster
4. **Storage**: At least 15GB of available disk space

## Quick Start

### 1. Verify Cluster is Running

```bash
kubectl cluster-info
kubectl get nodes
```

### 2. Check Default StorageClass

```bash
kubectl get storageclass
```

If no default StorageClass exists, apply the appropriate one:

```bash
# For kind or k3d
kubectl apply -f storageclass-local.yaml

# Or just the local-path StorageClass
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
EOF
```

### 3. Create Namespace

```bash
kubectl create namespace datalake
```

### 4. Install the Datalake

Using the local values file:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --create-namespace
```

Or with custom overrides:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set minio.persistence.size=10Gi \
  --set spark.worker.replicaCount=2 \
  --create-namespace
```

### 5. Verify Installation

```bash
# Check all pods are running
kubectl get pods -n datalake

# Check services
kubectl get svc -n datalake

# Check PVCs
kubectl get pvc -n datalake
```

## Accessing Services

### Using Port-Forward

The easiest way to access services locally:

```bash
# MinIO Console
kubectl port-forward -n datalake svc/minio 9001:9001

# Airflow Web UI
kubectl port-forward -n datalake svc/airflow 8080:8080

# Trino
kubectl port-forward -n datalake svc/trino 8080:8080

# Spark Master UI
kubectl port-forward -n datalake svc/spark-master 8080:8080

# Jupyter Notebook
kubectl port-forward -n datalake svc/jupyter 8888:8888

# Marquez Web UI
kubectl port-forward -n datalake svc/marquez-web 3000:3000
```

Then access in your browser:
- MinIO Console: http://localhost:9001
- Airflow: http://localhost:8080
- Trino: http://localhost:8080
- Spark: http://localhost:8080
- Jupyter: http://localhost:8888
- Marquez: http://localhost:3000

### Using NodePort (Alternative)

Modify the service type to NodePort:

```bash
helm upgrade datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set minio.service.type=NodePort \
  --set airflow.service.type=NodePort
```

Then get the NodePort:

```bash
kubectl get svc -n datalake
```

## Storage Configuration

### Default StorageClass

The `values-local.yaml` uses empty string `""` for `storageClass`, which means it will use the default StorageClass in your cluster.

### Custom StorageClass

To use a specific StorageClass:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set minio.persistence.storageClass=local-path \
  --set postgres.persistence.storageClass=local-path \
  --set airflow.persistence.logs.storageClass=local-path
```

### Disable Persistence (for testing)

For quick testing without persistence:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set minio.persistence.enabled=false \
  --set postgres.persistence.enabled=false \
  --set airflow.persistence.logs.enabled=false \
  --set airflow.persistence.plugins.enabled=false
```

## Resource Optimization

### Minimal Installation

For resource-constrained environments:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set jupyter.enabled=false \
  --set greatExpectations.enabled=false \
  --set marquez.enabled=false \
  --set tokern.enabled=false
```

### Custom Resource Limits

Adjust resources based on your machine:

```bash
helm install datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set trino.resources.limits.memory=1Gi \
  --set spark.master.resources.limits.memory=512Mi \
  --set spark.worker.resources.limits.memory=512Mi
```

## Cluster-Specific Notes

### kind (Kubernetes in Docker)

kind uses `local-path` provisioner by default. No additional configuration needed.

```bash
# Create a kind cluster with extra disk space
kind create cluster --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /tmp/kind-datalake
    containerPath: /var/local-path-provisioner
EOF
```

### k3d (k3s in Docker)

k3d also uses `local-path` provisioner by default.

```bash
# Create k3d cluster
k3d cluster create datalake --servers 1 --agents 2
```

### Docker Desktop

Docker Desktop uses `hostpath` provisioner. If it's not set as default:

```bash
kubectl patch storageclass hostpath -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### Minikube

Minikube uses `standard` StorageClass by default.

```bash
# Start Minikube with enough resources
minikube start --cpus 4 --memory 8192 --disk-size 50g

# Enable metrics-server for monitoring
minikube addons enable metrics-server
```

## Troubleshooting

### Pods Stuck in Pending

Check PVC status:

```bash
kubectl get pvc -n datalake
kubectl describe pvc <pvc-name> -n datalake
```

Ensure StorageClass exists:

```bash
kubectl get storageclass
```

### Out of Resources

Check node resources:

```bash
kubectl top nodes
kubectl describe nodes
```

Reduce resource requests in values:

```bash
helm upgrade datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set trino.resources.requests.memory=512Mi
```

### ImagePullBackOff

Check image pull policy and ensure you have internet connectivity:

```bash
kubectl describe pod <pod-name> -n datalake
```

### PVC Not Binding

For `WaitForFirstConsumer` binding mode, PVC binds only when a pod uses it:

```bash
kubectl describe pvc <pvc-name> -n datalake
kubectl get events -n datalake --sort-by='.lastTimestamp'
```

## Cleanup

### Uninstall Chart

```bash
helm uninstall datalake --namespace datalake
```

### Delete PVCs (if persistent data exists)

```bash
kubectl delete pvc -n datalake --all
```

### Delete Namespace

```bash
kubectl delete namespace datalake
```

### Delete Cluster (optional)

```bash
# kind
kind delete cluster

# k3d
k3d cluster delete datalake

# Minikube
minikube delete
```

## Performance Tips

1. **Increase Docker Resources**: Ensure Docker Desktop/Podman has at least 4 CPUs and 8GB RAM
2. **Use SSD**: Run cluster on SSD for better I/O performance
3. **Reduce Replicas**: Use single replicas for all services locally
4. **Disable Unused Services**: Disable services you don't need for testing
5. **Use emptyDir**: For ephemeral testing, disable persistence

## Monitoring

### Install Prometheus (optional)

If you want metrics collection:

```bash
# Using kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Enable ServiceMonitor
helm upgrade datalake . \
  --namespace datalake \
  --values values-local.yaml \
  --set serviceMonitor.enabled=true
```

### Access Prometheus and Grafana

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Grafana (default: admin/prom-operator)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## Next Steps

- [Quickstart Guide](QUICKSTART.md) - Getting started with the datalake
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - Architecture details
- [README](README.md) - Full documentation
