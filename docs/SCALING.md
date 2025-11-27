## Logstash Scaling Guide

## Overview

This document explains how to scale Logstash StatefulSet replicas and what happens when you change the replica count. Kibana does not need scaling as one replica is sufficient for the UI layer.

## Why Scale Logstash

Scale Logstash when you need to

- Handle increased log ingestion rate
- Distribute processing load across multiple pods
- Improve availability during pod failures
- Process larger volumes of log data

## StatefulSet Scaling Basics

Logstash runs as a StatefulSet which provides the following benefits

- Each pod gets a unique persistent identity
- Pods are created and terminated in order
- Each pod gets its own persistent volume automatically
- Pod names are predictable following pattern logstash-0, logstash-1, logstash-2

## What Happens When You Scale

#### Scaling Up from 1 to 2 Replicas

When you increase replicas from 1 to 2 the following happens

- New pod named logstash-1 is created
- New PVC named logstash-data-logstash-1 is automatically created
- New PV is bound to the new PVC
- Pod starts and mounts its dedicated storage
- Load balancer service starts routing traffic to both pods

Storage changes
- Before scaling you have logstash-data-logstash-0 PVC with 10Gi
- After scaling you have logstash-data-logstash-0 and logstash-data-logstash-1 each with 10Gi
- Total storage increases from 10Gi to 20Gi

#### Scaling Up from 2 to 3 Replicas

The same pattern continues

- Pod logstash-2 is created
- PVC logstash-data-logstash-2 is automatically created
- Total storage becomes 30Gi across 3 pods

#### Scaling Down from 3 to 2 Replicas

When you decrease replicas the behavior is different

- Pod logstash-2 is terminated first
- PVC logstash-data-logstash-2 is NOT automatically deleted
- PVC remains bound and retains data
- If you scale back up to 3 the same PVC is reused

Important notes about scaling down
- Data is never lost when scaling down
- PVCs remain even after pod deletion
- You must manually delete PVCs if you want to reclaim storage
- Scaling back up reuses existing PVCs preserving queue data

## How to Scale Logstash

#### Method 1 Using kubectl scale Command

This is the simplest method for temporary scaling

Scale up to 2 replicas

```bash
kubectl scale statefulset logstash --replicas=2 -n k3s-elk-stack
```

Scale up to 3 replicas

```bash
kubectl scale statefulset logstash --replicas=3 -n k3s-elk-stack
```

Scale down to 1 replica

```bash
kubectl scale statefulset logstash --replicas=1 -n k3s-elk-stack
```

Verify scaling

```bash
kubectl get pods -n k3s-elk-stack -l app=logstash
kubectl get pvc -n k3s-elk-stack
kubectl get statefulset logstash -n k3s-elk-stack
```

#### Method 2 Edit StatefulSet YAML File

This method persists the change in your configuration files

Edit the StatefulSet configuration file

```bash
nano logstash/logstash-statefulset.yaml
```

Find the replicas line and change the number

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: logstash
  namespace: k3s-elk-stack
spec:
  serviceName: logstash
  replicas: 3  # Change this number
  selector:
    matchLabels:
      app: logstash
```

Apply the changes

```bash
kubectl apply -f logstash/logstash-statefulset.yaml
```

Update deploy.sh to match

Edit deploy.sh and update the wait condition

```bash
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=3 \
  --timeout=300s \
  -n k3s-elk-stack
```

Change the 3 to match your desired replica count

## Monitoring Scaling Operations

#### Watch Pod Creation

Monitor pods being created in real-time

```bash
kubectl get pods -n k3s-elk-stack -l app=logstash -w
```

You will see pods created one at a time
- logstash-0 created first
- Once logstash-0 is ready then logstash-1 starts
- Once logstash-1 is ready then logstash-2 starts

#### Check StatefulSet Status

View detailed StatefulSet status

```bash
kubectl describe statefulset logstash -n k3s-elk-stack
```

Look for the following fields
- Replicas shows desired replica count
- Ready Replicas shows how many are ready
- Current Replicas shows current count

#### Verify PVC Creation

List all PVCs to see storage allocation

```bash
kubectl get pvc -n k3s-elk-stack
```

Expected output for 3 replicas

```
NAME                        STATUS   VOLUME   CAPACITY   ACCESS MODES
kibana-data-pvc             Bound    pv-xxx   5Gi        RWO
logstash-data-logstash-0    Bound    pv-xxx   10Gi       RWO
logstash-data-logstash-1    Bound    pv-xxx   10Gi       RWO
logstash-data-logstash-2    Bound    pv-xxx   10Gi       RWO
```

#### Check Storage Usage

Verify each pod has mounted storage

```bash
kubectl exec -n k3s-elk-stack logstash-0 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk-stack logstash-1 -- df -h /usr/share/logstash/data
kubectl exec -n k3s-elk-stack logstash-2 -- df -h /usr/share/logstash/data
```

## Load Distribution

#### How Traffic is Distributed

The logstash-lb service uses ClusterIP with no session affinity

- Traffic is distributed round-robin across all ready pods
- Each connection may go to a different pod
- No guarantee of even distribution for low volume traffic
- High volume traffic naturally balances across pods

#### Verify Load Balancing

Send test traffic and check pod logs

```bash
for i in {1..10}; do
  kubectl run test-logger-$i --rm -it --image=busybox -- sh -c "echo '{\"message\":\"Test $i\"}' | nc logstash-lb.k3s-elk-stack 5044"
done
```

Check which pods received messages

```bash
kubectl logs -n k3s-elk-stack logstash-0 --tail=20
kubectl logs -n k3s-elk-stack logstash-1 --tail=20
kubectl logs -n k3s-elk-stack logstash-2 --tail=20
```

## Resource Planning

#### Per Pod Resource Requirements

Each Logstash pod requires

- Memory request of 512Mi
- Memory limit of 1Gi
- CPU request of 200m
- CPU limit of 500m
- Storage of 10Gi per pod

#### Calculate Total Resources Needed

For desired replica count multiply by pod requirements

Example for 3 replicas
- Total memory needed is 1.5Gi requests and 3Gi limits
- Total CPU needed is 600m requests and 1.5 CPU limits
- Total storage needed is 30Gi plus 5Gi for Kibana equals 35Gi total

#### Node Capacity Check

Before scaling verify node has sufficient resources

```bash
kubectl describe node your-node-name
```

Look for allocatable resources and current allocation

## Storage Management

#### Persistent Volume Lifecycle

Understanding PVC behavior during scaling

When scaling up
- New PVC is automatically created from volumeClaimTemplate
- PVC requests 10Gi storage
- PV is dynamically provisioned by local-path provisioner
- Default location is /var/lib/rancher/k3s/storage/pvc-UUID

When scaling down
- Pod is deleted
- PVC remains bound with status Bound
- Data is retained in PVC
- PV stays attached to PVC

#### Manual PVC Cleanup

If you scale down and want to reclaim storage you must manually delete PVCs

List orphaned PVCs after scaling down

```bash
kubectl get pvc -n k3s-elk-stack
```

Delete specific PVC

```bash
kubectl delete pvc logstash-data-logstash-2 -n k3s-elk-stack
```

Warning this permanently deletes data in that PVC

#### Viewing PVC Data Location

Find where PVC data is stored on the host

```bash
kubectl get pv
```

Look for the path in hostPath or local provisioner metadata

For k3s local-path provisioner

```bash
sudo ls -lah /var/lib/rancher/k3s/storage/
```

## Scaling Scenarios

#### Scenario 1 Initial Deployment to Production

Start with 1 replica for initial setup and testing

Current state in logstash-statefulset.yaml

```yaml
replicas: 1
```

No changes needed for initial deployment

#### Scenario 2 Increase Load Handling

When log volume increases scale to 2 replicas

Edit logstash/logstash-statefulset.yaml

```yaml
replicas: 2
```

Edit deploy.sh

```bash
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=2 \
  --timeout=300s \
  -n k3s-elk-stack
```

Apply changes

```bash
kubectl apply -f logstash/logstash-statefulset.yaml
```

Wait for new pod

```bash
kubectl get pods -n k3s-elk-stack -w
```

Verify both PVCs exist

```bash
kubectl get pvc -n k3s-elk-stack | grep logstash
```

Expected output

```
logstash-data-logstash-0    Bound    10Gi
logstash-data-logstash-1    Bound    10Gi
```

#### Scenario 3 High Availability Setup

For maximum availability scale to 3 replicas

Edit logstash/logstash-statefulset.yaml

```yaml
replicas: 3
```

Edit deploy.sh

```bash
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=3 \
  --timeout=300s \
  -n k3s-elk-stack
```

Apply and verify

```bash
kubectl apply -f logstash/logstash-statefulset.yaml
kubectl get pods -n k3s-elk-stack -l app=logstash
```

#### Scenario 4 Scaling Down After Peak

After high load period scale back to 1 replica

Edit logstash/logstash-statefulset.yaml

```yaml
replicas: 1
```

Edit deploy.sh

```bash
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=1 \
  --timeout=300s \
  -n k3s-elk-stack
```

Apply changes

```bash
kubectl apply -f logstash/logstash-statefulset.yaml
```

Pods logstash-2 and logstash-1 will terminate

PVCs logstash-data-logstash-1 and logstash-data-logstash-2 remain

Optionally delete unused PVCs

```bash
kubectl delete pvc logstash-data-logstash-1 -n k3s-elk-stack
kubectl delete pvc logstash-data-logstash-2 -n k3s-elk-stack
```

## Troubleshooting Scaling Issues

#### Pod Stuck in Pending

Check PVC status

```bash
kubectl describe pvc logstash-data-logstash-1 -n k3s-elk-stack
```

Common causes
- Insufficient storage on node
- PV not available
- Storage class issues

#### Pod CrashLoopBackOff After Scaling

Check pod logs

```bash
kubectl logs -n k3s-elk-stack logstash-1
```

Common causes
- Configuration errors
- Insufficient resources
- Port conflicts

#### Uneven Traffic Distribution

Verify service endpoints

```bash
kubectl get endpoints logstash-lb -n k3s-elk-stack
```

All ready pods should be listed as endpoints

#### Scaling Takes Too Long

Check pod events

```bash
kubectl describe pod logstash-1 -n k3s-elk-stack
```

Common delays
- Image pull time
- PVC provisioning time
- Pod initialization and readiness probes

## Best Practices

Recommendations for scaling

- Start with 1 replica for development and testing
- Scale to 2 replicas for production baseline
- Scale to 3 or more for high availability or high load
- Monitor resource usage before scaling up
- Clean up unused PVCs after scaling down
- Update both YAML files and deploy.sh when making permanent changes
- Test scaling in non-production first
- Document your scaling decisions

## Summary

Key points to remember

- Logstash uses StatefulSet with volumeClaimTemplates
- Each replica gets its own 10Gi PVC automatically
- Scaling up creates new PVCs automatically
- Scaling down does NOT delete PVCs automatically
- Edit replicas in logstash-statefulset.yaml for permanent changes
- Update deploy.sh wait condition to match replica count
- Kibana does not need scaling as 1 replica is sufficient
- Storage scales linearly with replica count at 10Gi per pod

## Related Documentation

- Storage Configuration in [STORAGE.md](STORAGE.md)
- Deployment Guide in [README.md](README.md)
