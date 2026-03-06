# k8s-health-check

Quick bash script that checks the basics on a Kubernetes cluster. Nothing fancy, just the stuff I got tired of checking manually every morning.

## What it checks

- Node status and resource pressure conditions
- Pods in CrashLoopBackOff or stuck Pending
- Certificates expiring within 30 days
- PVCs that are unbound
- Deployments with unavailable replicas

## Usage

```bash
chmod +x health-check.sh
./health-check.sh
```

## Example output

```
=== K8s Health Check ===
Nodes:           3/3 Ready
Pod Issues:      2 (1 CrashLoopBackOff, 1 Pending)
Unbound PVCs:    0
Unavailable:     1 deployment (nginx-ingress)
```

## Requirements

- `kubectl` configured and pointing at your cluster

## License

MIT
