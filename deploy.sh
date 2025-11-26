set -e

echo "Deploying ELK Stack to k3s-elk-stack namespace..."

echo "Creating namespace..."
kubectl apply -f namespace/

echo "Deploying Logstash..."
kubectl apply -f logstash/logstash-config.yaml
kubectl apply -f logstash/logstash-deployment.yaml

echo "Deploying Kibana..."
kubectl apply -f kibana/kibana-deployment.yaml

echo "Deploying Grafana..."
kubectl apply -f grafana/grafana-deployment.yaml

echo "Waiting for deployments to be ready..."
kubectl wait deployment/logstash \
  --for=condition=Available \
  --timeout=300s \
  -n k3s-elk-stack

kubectl wait deployment/kibana \
  --for=condition=Available \
  --timeout=300s \
  -n k3s-elk-stack

kubectl wait deployment/grafana \
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
echo "Grafana: http://<node-ip>:30300 (admin/admin)"
echo "Logstash: logstash.k3s-elk-stack:5044"
