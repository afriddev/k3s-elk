#!/bin/bash
set -e

echo "=========================================="
echo "ELK Stack Deployment"
echo "=========================================="
echo ""

echo "[1/7] Creating namespace..."
kubectl apply -f namespace/

echo ""
echo "[2/7] Creating storage resources..."
kubectl apply -f storage/elasticsearch-storageclass.yaml
kubectl apply -f storage/logstash-storageclass.yaml
kubectl apply -f storage/kibana-storageclass.yaml
kubectl apply -f storage/pv/
kubectl apply -f storage/pvc/

echo ""
echo "[3/7] Creating ConfigMaps..."
kubectl apply -f configmaps/

echo ""
echo "[4/7] Deploying Elasticsearch..."
kubectl apply -f services/headless/elasticsearch-headless.yaml
kubectl apply -f services/nodeport/elasticsearch-nodeport.yaml
kubectl apply -f statefulsets/elasticsearch-statefulset.yaml

echo ""
echo "[5/7] Deploying Logstash..."
kubectl apply -f services/headless/logstash-headless.yaml
kubectl apply -f services/nodeport/logstash-nodeport.yaml
kubectl apply -f statefulsets/logstash-statefulset.yaml

echo ""
echo "[6/7] Deploying Kibana..."
kubectl apply -f services/nodeport/kibana-nodeport.yaml
kubectl apply -f deployments/kibana-deployment.yaml

echo ""
echo "[7/7] Waiting for deployments to be ready..."

echo "  - Waiting for Elasticsearch..."
kubectl wait statefulset/elk-elasticsearch \
  --for=jsonpath='{.status.readyReplicas}'=1 \
  --timeout=600s \
  -n k3s-elk

echo "  - Waiting for Logstash..."
kubectl wait statefulset/elk-logstash \
  --for=jsonpath='{.status.readyReplicas}'=1 \
  --timeout=300s \
  -n k3s-elk

echo "  - Waiting for Kibana..."
kubectl wait deployment/elk-kibana \
  --for=condition=Available \
  --timeout=300s \
  -n k3s-elk

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""

kubectl get pods -n k3s-elk

echo ""
echo "Access Points:"
echo "  Elasticsearch: http://<node-ip>:30920"
echo "  Kibana:        http://<node-ip>:30561"
echo "  Logstash:      http://<node-ip>:30044"
echo ""
echo "Internal Endpoints:"
echo "  Elasticsearch: http://elk-elasticsearch-0.elk-elasticsearch-headless.k3s-elk.svc.cluster.local:9200"
echo "  Logstash:      elk-logstash-headless.k3s-elk.svc.cluster.local:5044"
echo ""
echo "For usage instructions, see docs/usage.md"
echo ""
