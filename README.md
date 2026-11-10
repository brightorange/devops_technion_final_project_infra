# devops_technion_final_project_infra

Infrastructure and deployment for the shop API
([app repo](https://github.com/brightorange/devops_technion_final_project)).

## Deploy to Minikube (plain manifests)

Every `kubectl` command names its cluster with `--context minikube`, so it can
never hit whatever cluster happens to be the current context.

```bash
minikube start --driver=docker --cpus=4 --memory=8g

# 0. Ingress controller. An Ingress resource is only data; without a
#    controller running, nothing routes.
minikube addons enable ingress

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

# 4. Check
kubectl --context minikube -n shop get pods
```

## Reach the API

Through the Ingress, at `http://shop.local`:

```bash
# One time: point the hostname at localhost
echo "127.0.0.1 shop.local" | sudo tee -a /etc/hosts

# Leave running in its own terminal. With the docker driver the node IP
# (minikube ip) is inside Docker's VM and unreachable from macOS, so the
# tunnel is what publishes the ingress controller on 127.0.0.1.
minikube tunnel

curl http://shop.local/health/ready
curl http://shop.local/api/products
```

Without the hosts entry, the same thing with the header set by hand:

```bash
kubectl --context minikube -n ingress-nginx \
  port-forward svc/ingress-nginx-controller 8080:80
curl -H "Host: shop.local" http://localhost:8080/api/products
```

Bypassing the Ingress entirely, straight to the Service:

```bash
kubectl --context minikube -n shop port-forward svc/api 8080:80
curl localhost:8080/health/ready
```

Note that `port-forward` on a Service tunnels to a single pod, so it does not
exercise load balancing. To see that, call the Service from inside the cluster.
