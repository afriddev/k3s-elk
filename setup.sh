#!/bin/bash
set -e

echo "=========================================="
echo "ELK Stack Storage Setup"
echo "=========================================="
echo ""

NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Target Kubernetes node: $NODE_NAME"
echo ""

echo "Creating storage directories using kubectl debug..."
kubectl debug node/$NODE_NAME -it --image=busybox -- sh -c "
  echo 'Creating Elasticsearch storage directory...'
  mkdir -p /host/mnt/ssd/elasticsearch/node-0
  
  echo 'Creating Kibana storage directory...'
  mkdir -p /host/mnt/ssd/kibana-data
  
  echo 'Creating Logstash storage directory...'
  mkdir -p /host/mnt/ssd/logstash/node-0
  
  echo 'Setting permissions for Elasticsearch (UID 1000)...'
  chmod -R 755 /host/mnt/ssd/elasticsearch
  chown -R 1000:1000 /host/mnt/ssd/elasticsearch

  echo 'Setting permissions for Logstash (UID 1000)...'
  chmod -R 755 /host/mnt/ssd/logstash
  chown -R 1000:1000 /host/mnt/ssd/logstash
  
  echo 'Setting permissions for Kibana...'
  chmod -R 777 /host/mnt/ssd/kibana-data
  
  echo 'Done!'
"

echo ""
echo "=========================================="
echo "Storage Setup Complete"
echo "=========================================="
echo ""
echo "Created directories:"
echo "  - /mnt/ssd/elasticsearch/node-0 (Elasticsearch data)"
echo "  - /mnt/ssd/kibana-data (Kibana saved objects)"
echo ""
echo "Note: Logstash uses dynamic PVC provisioning (no manual setup needed)"
echo ""
echo "Next step: Run ./deploy.sh to deploy the ELK stack"
echo ""
