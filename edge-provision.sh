#!/bin/bash

provision(){
echo "***Start Docker in Docker***"
dockerd --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 &
echo "***Authenticating with Azure CLI***"
az login --service-principal -u $spAppUrl -p $spPassword --tenant $tenantId
az account set --subscription $subscriptionId
echo "***Configuring IoT Edge Device***"
az iot hub device-identity create --device-id $(hostname) --hub-name $iothub_name --edge-enabled
connectionString=$(az iot hub device-identity show-connection-string --device-id $(hostname) --hub-name $iothub_name | jq -r '.cs')
az iot hub device-twin update --device-id $(hostname) --hub-name $iothub_name --set tags='{"environment":"'$environment'"}'
echo "***Configuring and Starting IoT Edge Runtime***"

IP=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

cat <<EOF > /etc/iotedge/config.yaml
provisioning:
  source: "manual"
  device_connection_string: "$connectionString"
agent:
  name: "edgeAgent"
  type: "docker"
  env: {}
  config:
    image: "mcr.microsoft.com/azureiotedge-agent:1.0"
    auth: {}
hostname: $(cat /proc/sys/kernel/hostname)
connect:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
listen:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
homedir: "/var/lib/iotedge"
moby_runtime:
  docker_uri: "/var/run/docker.sock"
  network: "azure-iot-edge"
EOF

cat /etc/iotedge/config.yaml

iotedged -c /etc/iotedge/config.yaml

}

# Check Arguments
provision