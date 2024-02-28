# Install kubectl
az aks install-cli --only-show-errors

# Get AKS credentials
az aks get-credentials \
  --admin \
  --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --only-show-errors

# Check if the cluster is private or not
private=$(az aks show --name $clusterName \
  --resource-group $resourceGroupName \
  --subscription $subscriptionId \
  --query apiServerAccessProfile.enablePrivateCluster \
  --output tsv)

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh -s
chmod 700 get_helm.sh
./get_helm.sh &>/dev/null

# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jetstack https://charts.jetstack.io

# Update Helm repos
helm repo update

# initialize variables
applicationGatewayForContainersName=''
diagnosticSettingName="DefaultDiagnosticSettings"

if [[ $private == 'true' ]]; then
  # Log whether the cluster is public or private
  echo "$clusterName AKS cluster is private"

  # Install Prometheus
  command="helm upgrade prometheus prometheus-community/kube-prometheus-stack \ù
  --install \
  --create-namespace \
  --namespace prometheus \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false"

  az aks command invoke \
    --name $clusterName \
    --resource-group $resourceGroupName \
    --subscription $subscriptionId \
    --command "$command"

  # Install certificate manager
  command="helm upgrade cert-manager jetstack/cert-manager \
    --install \
    --create-namespace \
    --namespace cert-manager \
    --version v1.8.0 \
    --set installCRDs=true \
    --set nodeSelector.\"kubernetes\.io/os\"=linux \
    --set \"extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}\""

  az aks command invoke \
    --name $clusterName \
    --resource-group $resourceGroupName \
    --subscription $subscriptionId \
    --command "$command"

  if [[ -n "$namespace" && \
        -n "$serviceAccountName" ]]; then
    # Create workload namespace
    command="kubectl create namespace $namespace"

    az aks command invoke \
      --name $clusterName \
      --resource-group $resourceGroupName \
      --subscription $subscriptionId \
      --command "$command"

    # Create service account
    command="cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $workloadManagedIdentityClientId
    azure.workload.identity/tenant-id: $tenantId
  labels:
    azure.workload.identity/use: "true"
  name: $serviceAccountName
  namespace: $namespace
EOF"

    az aks command invoke \
      --name $clusterName \
      --resource-group $resourceGroupName \
      --subscription $subscriptionId \
      --command "$command"
  fi

  if [[ "$applicationGatewayForContainersEnabled" == "true" \
      && -n "$applicationGatewayForContainersManagedIdentityClientId" \
      && -n "$applicationGatewayForContainersSubnetId" ]]; then
    
    # Install the Application Load Balancer Controller
    command="helm upgrade alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
    --install \
    --create-namespace \
    --namespace $applicationGatewayForContainersNamespace \
    --version 1.0.0 \
    --set albController.podIdentity.clientID=$applicationGatewayForContainersManagedIdentityClientId"

    az aks command invoke \
    --name $clusterName \
    --resource-group $resourceGroupName \
    --subscription $subscriptionId \
    --command "$command"

    # Create workload namespace
    command="kubectl create namespace alb-infra"

    az aks command invoke \
    --name $clusterName \
    --resource-group $resourceGroupName \
    --subscription $subscriptionId \
    --command "$command"

    if [[ "$applicationGatewayForContainersType" == "managed" ]]; then
      # Define the ApplicationLoadBalancer resource, specifying the subnet ID the Application Gateway for Containers association resource should deploy into. 
      # The association establishes connectivity from Application Gateway for Containers to the defined subnet (and connected networks where applicable) to 
      # be able to proxy traffic to a defined backend.
      command="kubectl apply -f - <<EOF
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb
  namespace: alb-infra
spec:
  associations:
  - $applicationGatewayForContainersSubnetId
EOF"
      az aks command invoke \
      --name $clusterName \
      --resource-group $resourceGroupName \
      --subscription $subscriptionId \
      --command "$command"

      if [[ -n $nodeResourceGroupName ]]; then \
        echo -n "Retrieving the resource id of the Application Gateway for Containers..."
        counter=1
        while [ $counter -le 600 ]
        do
          # Retrieve the resource id of the managed Application Gateway for Containers resource
          applicationGatewayForContainersId=$(az resource list \
            --resource-type "Microsoft.ServiceNetworking/TrafficControllers" \
            --resource-group $nodeResourceGroupName \
            --query [0].id \
            --output tsv)
          if [[ -n $applicationGatewayForContainersId ]]; then
            echo 
            break 
          else
            echo -n '.'
            counter=$((counter + 1))
            sleep 1
          fi
        done

        if [[ -n $applicationGatewayForContainersId ]]; then
          applicationGatewayForContainersName=$(basename $applicationGatewayForContainersId)
          echo "[$applicationGatewayForContainersId] resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers successfully retrieved"
        else
          echo "Failed to retrieve the resource id of the Application Gateway for Containers"
          exit -1
        fi

        # Check if the diagnostic setting already exists for the Application Gateway for Containers
        echo "Checking if the [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers actually exists..."
        result=$(az monitor diagnostic-settings show \
          --name $diagnosticSettingName \
          --resource $applicationGatewayForContainersId \
          --query name \
          --output tsv 2>/dev/null)

        if [[ -z $result ]]; then
          echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers does not exist"
          echo "Creating [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers..."

          # Create the diagnostic setting for the Application Gateway for Containers
          az monitor diagnostic-settings create \
            --name $diagnosticSettingName \
            --resource $applicationGatewayForContainersId \
            --logs '[{"categoryGroup": "allLogs", "enabled": true}]' \
            --metrics '[{"category": "AllMetrics", "enabled": true}]' \
            --workspace $workspaceId \
            --only-show-errors 1>/dev/null

          if [[ $? == 0 ]]; then
            echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers successfully created"
          else
            echo "Failed to create [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers"
            exit -1
          fi
        else
          echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers already exists"
        fi
      fi
    fi
  fi
else
  # Log whether the cluster is public or private
  echo "$clusterName AKS cluster is public"

  # Install Prometheus
  echo "Installing Prometheus..."
  helm upgrade prometheus prometheus-community/kube-prometheus-stack \
    --install \
    --create-namespace \
    --namespace prometheus \
    --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

  if [[ $? == 0 ]]; then
    echo "Prometheus successfully installed"
  else
    echo "Failed to install Prometheus"
    exit -1
  fi

  # Install certificate manager
  echo "Installing certificate manager..."
  helm upgrade cert-manager jetstack/cert-manager \
    --install \
    --create-namespace \
    --namespace cert-manager \
    --version v1.8.0 \
    --set installCRDs=true \
    --set nodeSelector."kubernetes\.io/os"=linux \
    --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}"

  if [[ $? == 0 ]]; then
    echo "Certificate manager successfully installed"
  else
    echo "Failed to install certificate manager"
    exit -1
  fi

  if [[ -n "$namespace" && \
        -n "$serviceAccountName" ]]; then
    # Create workload namespace
    result=$(kubectl get namespace -o 'jsonpath={.items[?(@.metadata.name=="'$namespace'")].metadata.name'})

    if [[ -n $result ]]; then
        echo "$namespace namespace already exists in the cluster"
    else
        echo "$namespace namespace does not exist in the cluster"
        echo "Creating $namespace namespace in the cluster..."
        kubectl create namespace $namespace
    fi

    # Create service account
    echo "Creating $serviceAccountName service account..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: $workloadManagedIdentityClientId
    azure.workload.identity/tenant-id: $tenantId
  labels:
    azure.workload.identity/use: "true"
  name: $serviceAccountName
  namespace: $namespace
EOF
  fi

  if [[ "$applicationGatewayForContainersEnabled" == "true" \
        && -n "$applicationGatewayForContainersManagedIdentityClientId" \
        && -n "$applicationGatewayForContainersSubnetId" ]]; then
      
      # Install the Application Load Balancer
      echo "Installing Application Load Balancer Controller in $applicationGatewayForContainersNamespace namespace using $applicationGatewayForContainersManagedIdentityClientId managed identity..."
      helm upgrade alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
      --install \
      --create-namespace \
      --namespace $applicationGatewayForContainersNamespace \
      --version 1.0.0 \
      --set albController.namespace=$applicationGatewayForContainersNamespace \
      --set albController.podIdentity.clientID=$applicationGatewayForContainersManagedIdentityClientId
    
    if [[ $? == 0 ]]; then
      echo "Application Load Balancer Controller successfully installed"
    else
      echo "Failed to install Application Load Balancer Controller"
      exit -1
    fi

    if [[ "$applicationGatewayForContainersType" == "managed" ]]; then
      # Create alb-infra namespace
      albInfraNamespace='alb-infra'
      result=$(kubectl get namespace -o 'jsonpath={.items[?(@.metadata.name=="'$albInfraNamespace'")].metadata.name'})

      if [[ -n $result ]]; then
          echo "$albInfraNamespace namespace already exists in the cluster"
      else
          echo "$albInfraNamespace namespace does not exist in the cluster"
          echo "Creating $albInfraNamespace namespace in the cluster..."
          kubectl create namespace $albInfraNamespace
      fi

      # Define the ApplicationLoadBalancer resource, specifying the subnet ID the Application Gateway for Containers association resource should deploy into. 
      # The association establishes connectivity from Application Gateway for Containers to the defined subnet (and connected networks where applicable) to 
      # be able to proxy traffic to a defined backend.
      echo "Creating ApplicationLoadBalancer resource..."
      kubectl apply -f - <<EOF
apiVersion: alb.networking.azure.io/v1
kind: ApplicationLoadBalancer
metadata:
  name: alb
  namespace: alb-infra
spec:
  associations:
  - $applicationGatewayForContainersSubnetId
EOF
      if [[ -n $nodeResourceGroupName ]]; then \
        echo -n "Retrieving the resource id of the Application Gateway for Containers..."
        counter=1
        while [ $counter -le 20 ]
        do
          # Retrieve the resource id of the managed Application Gateway for Containers resource
          applicationGatewayForContainersId=$(az resource list \
            --resource-type "Microsoft.ServiceNetworking/TrafficControllers" \
            --resource-group $nodeResourceGroupName \
            --query [0].id \
            --output tsv)
          if [[ -n $applicationGatewayForContainersId ]]; then
            echo 
            break 
          else
            echo -n '.'
            counter=$((counter + 1))
            sleep 1
          fi
        done

        if [[ -n $applicationGatewayForContainersId ]]; then
          applicationGatewayForContainersName=$(basename $applicationGatewayForContainersId)
          echo "[$applicationGatewayForContainersId] resource id of the [$applicationGatewayForContainersName] Application Gateway for Containers successfully retrieved"
        else
          echo "Failed to retrieve the resource id of the Application Gateway for Containers"
          exit -1
        fi

        # Check if the diagnostic setting already exists for the Application Gateway for Containers
        echo "Checking if the [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers actually exists..."
        result=$(az monitor diagnostic-settings show \
          --name $diagnosticSettingName \
          --resource $applicationGatewayForContainersId \
          --query name \
          --output tsv 2>/dev/null)

        if [[ -z $result ]]; then
          echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers does not exist"
          echo "Creating [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers..."

          # Create the diagnostic setting for the Application Gateway for Containers
          az monitor diagnostic-settings create \
            --name $diagnosticSettingName \
            --resource $applicationGatewayForContainersId \
            --logs '[{"categoryGroup": "allLogs", "enabled": true}]' \
            --metrics '[{"category": "AllMetrics", "enabled": true}]' \
            --workspace $workspaceId \
            --only-show-errors 1>/dev/null

          if [[ $? == 0 ]]; then
            echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers successfully created"
          else
            echo "Failed to create [$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers"
            exit -1
          fi
        else
          echo "[$diagnosticSettingName] diagnostic setting for the [$applicationGatewayForContainersName] Application Gateway for Containers already exists"
        fi
      fi
    fi
  fi
fi

# Create output as JSON file
echo '{}' |
  jq --arg x $applicationGatewayForContainersName '.applicationGatewayForContainersName=$x' |
  jq --arg x $namespace '.namespace=$x' |
  jq --arg x $serviceAccountName '.serviceAccountName=$x' |
  jq --arg x 'prometheus' '.prometheus=$x' |
  jq --arg x 'cert-manager' '.certManager=$x' >$AZ_SCRIPTS_OUTPUT_PATH