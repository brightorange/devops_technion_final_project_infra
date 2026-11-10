# devops_technion_final_project_infra

Infrastructure and deployment for the shop API
([app repo](https://github.com/brightorange/devops_technion_final_project)).

## Deploy to Minikube (plain manifests)

Every `kubectl` command names its cluster with `--context minikube`, so it can
never hit whatever cluster happens to be the current context.

```bash
minikube start --driver=docker --cpus=4 --memory=8g

# 1. Build the image in the app repo and load it into Minikube
docker compose -f ../devops_technion_final_project/docker-compose.yml build
minikube image load shop-api:dev

# 2. Namespace, then the DB secret (never committed)
kubectl --context minikube apply -f k8s/00-namespace.yaml
kubectl --context minikube -n shop create secret generic postgres-credentials \
  --from-literal=DB_USER=shop \
  --from-literal=DB_PASSWORD="$(openssl rand -base64 18)"

# 3. Everything else
kubectl --context minikube apply -f k8s/

# 4. Check and reach the API
kubectl --context minikube -n shop get pods
kubectl --context minikube -n shop port-forward svc/api 8080:80
curl localhost:8080/health/ready
```
