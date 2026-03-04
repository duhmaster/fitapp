# Kubernetes

Minimal manifests to run the FITFLOW API on a cluster. Postgres and Redis must exist in the cluster or be reachable (e.g. managed services).

## Prerequisites

- Cluster with Postgres and Redis (or point `DB_HOST` / `REDIS_ADDR` to your services)
- API image built and available to the cluster (e.g. push to a registry and set `image` in deployment)

## Apply

```bash
# Create namespace and config
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml

# Create secret from example (edit values first)
cp secret.yaml.example secret.yaml
# Edit secret.yaml with real DB_PASSWORD, JWT_SECRET, etc.
kubectl apply -f secret.yaml

# Deploy API (update deployment.yaml image to your registry if needed)
kubectl apply -f deployment.yaml
```

## Image

Build and push your image, then set in `deployment.yaml`:

```yaml
containers:
  - name: api
    image: your-registry/fitflow-api:v1
    imagePullPolicy: Always
```

## Ingress (optional)

Expose the service via your Ingress controller; backend service is `fitflow-api.fitflow.svc.cluster.local:8080`.

## Health

- Liveness: `GET /health/live`
- Readiness: `GET /health/ready`
