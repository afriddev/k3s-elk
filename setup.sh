#!/bin/bash

set -e

echo "Setting up ELK Stack storage directories..."

echo "Creating storage directories in /mnt/ssd..."
sudo mkdir -p /mnt/ssd/kibana-data

echo "Setting permissions..."
sudo chmod -R 777 /mnt/ssd/kibana-data

echo ""
echo "Storage directories created successfully!"
echo ""
echo "Directories:"
echo "  - /mnt/ssd/kibana-data"
echo ""
echo "Note: Logstash uses dynamic PVC provisioning via StatefulSet"
echo ""
echo "Next step: Run ./deploy.sh to deploy the ELK stack"
