set -e

echo "Deploying ELK Stack to k3s-elk-stack namespace..."

echo "Creating namespace..."
kubectl apply -f namespace/

echo "Creating persistent storage..."
kubectl apply -f storage/

echo "Waiting for PVCs to be bound..."
sleep 5

echo "Deploying Logstash..."
kubectl apply -f logstash/logstash-config.yaml
kubectl apply -f logstash/logstash-statefulset.yaml
kubectl apply -f logstash/logstash-service-headless.yaml
kubectl apply -f logstash/logstash-service.yaml

echo "Deploying Kibana..."
kubectl apply -f kibana/kibana-deployment.yaml
kubectl apply -f kibana/kibana-service.yaml

echo "Waiting for deployments to be ready..."
kubectl wait statefulset/logstash \
  --for=jsonpath='{.status.readyReplicas}'=1 \
  --timeout=300s \
  -n k3s-elk-stack

kubectl wait deployment/kibana \
  --for=condition=Available \
  --timeout=300s \
  -n k3s-elk-stack

echo ""
echo "Deployment complete!"
echo ""
kubectl get pods -n k3s-elk-stack
echo ""
echo "Access Points:"
echo "Kibana: http://<node-ip>:30561"
echo "Logstash: http://<node-ip>:30044"
echo "Logstash internal: logstash.k3s-elk-stack:5044"
