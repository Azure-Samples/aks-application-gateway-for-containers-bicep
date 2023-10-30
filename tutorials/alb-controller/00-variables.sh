# AKS
location="EastUS"
aksName='TanAks'
aksResourceGroupName='TanRG'

# Azure Subscription and Tenant
subscriptionId=$(az account show --query id --output tsv)
subscriptionName=$(az account show --query name --output tsv)
tenantId=$(az account show --query tenantId --output tsv)

# Managed Identity Federation
managedIdentityName='AzureAlbIdentity'
federatedIdentityName='azure-alb-identity'
namespace="azure-alb-system"
serviceAccountName="alb-controller-sa"

# Virtual Network
virtualNetworkName='TanVnet'
subnetName="AppGwSubnet"
subnetAddressPrefix="10.243.3.0/24"

# Application Gateway for Containers
applicationGatewayForContainersName='TanApplicationGatewayForContainers'
associationName="${subnetName}Association"
frontendName="DefaultFrontend"
multiSiteFrontendName="MultiSiteFrontend"
routingFrontendName="RoutingFrontend"
sslOffloadingFrontendName="SslOffloadingFrontend"
trafficSplittingFrontendName="TrafficSplittingFrontend"

# Diagnostic Settings
diagnosticSettingName="DefaultDiagnosticSettings"
logAnalyticsWorkspaceName="TanLogAnalytics"