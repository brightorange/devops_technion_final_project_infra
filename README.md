# devops_technion_final_project_infra

Infrastructure and deployment for the shop API
([app repo](https://github.com/brightorange/devops_technion_final_project)).

`helm/shop` is the deployment. It was derived from plain manifests, which are
in the history up to [PR #1](https://github.com/brightorange/devops_technion_final_project_infra/pull/1)
if you want the before/after.

Every command names its cluster explicitly (`--kube-context` / `--context`), so
it can never hit whatever cluster happens to be the current context.

## Deploy to Minikube (Helm)

```bash
minikube start --driver=docker --cpus=4 --memory=8g

# 0. Ingress controller. An Ingress resource is only data; without a
#    controller running, nothing routes.
minikube addons enable ingress

# 1. Build the image in the app repo and load it into Minikube
docker compose -f ../devops_technion_final_project/docker-compose.yml build
minikube image load shop-api:dev

# 2. Namespace, then the DB secret. The secret is created out of band so the
#    password is never stored in git; the chart only references it by name.
kubectl --context minikube create namespace shop
kubectl --context minikube -n shop create secret generic postgres-credentials \
  --from-literal=DB_USER=shop \
  --from-literal=DB_PASSWORD="$(openssl rand -base64 18)"

# 3. Install
helm install shop helm/shop -n shop --kube-context minikube --wait
```

Day-to-day:

```bash
helm upgrade shop helm/shop -n shop --kube-context minikube --wait
helm upgrade shop helm/shop -n shop --kube-context minikube --set api.replicas=3
helm history shop -n shop --kube-context minikube
helm rollback shop 1 -n shop --kube-context minikube
helm template shop helm/shop            # render locally, change nothing
helm diff upgrade shop helm/shop        # needs the helm-diff plugin
```

The migration runs itself. `db-migrate` is a `post-install,pre-upgrade` hook, so
every upgrade applies the schema before the new API pods roll out. Its
`before-hook-creation` delete policy recreates the Job each time, which is what
makes it re-runnable at all — a Job's `spec.template` is immutable, so plain
`kubectl apply` on a changed Job fails.

It is `post-install` rather than `pre-install` because on a first install
nothing exists yet, and a pre-install hook would sit waiting for a Postgres that
Helm has not created.

Changing a value in the ConfigMap triggers a rollout on its own: the API pod
template carries a `checksum/config` annotation over the rendered ConfigMap.
Without it, environment variables are read once at container start and config
edits are silently ignored.

## Reach the API

Through the Ingress, at `http://shop.local`:

```bash
# One time: point the hostname at localhost
echo "127.0.0.1 shop.local" | sudo tee -a /etc/hosts

# Leave running in its own terminal. With the docker driver the node IP
# (minikube ip) is inside Docker's VM and unreachable from macOS, so the
# tunnel is what publishes the ingress controller on 127.0.0.1.
minikube tunnel

curl http://shop.local/api/products
```

Only `/api` is routed. `/health/*` returns 404 through the ingress on purpose —
the probes are for the kubelet, which reaches them directly on the pod IP. To
check health by hand, go to the Service or the pod instead.

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
