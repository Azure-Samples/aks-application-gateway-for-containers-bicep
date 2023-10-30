# Certificate Manager
cmNamespace="cert-manager"
cmRepoName="jetstack"
cmRepoUrl="https://charts.jetstack.io"
cmChartName="cert-manager"
cmReleaseName="cert-manager"
cmVersion="v1.8.0"

# Application Gateway for Containers
applicationGatewayForContainersName='TanApplicationGatewayForContainers'
resourceGroupName='TanRG'

# Application Load Balancer 
applicationLoadBalancerName="alb"
applicationLoadBalancerNamespace="alb-infra"

# Demo
namespace="agfc-demo"
gatewayName="echo-gateway"
issuerName="letsencrypt"
httpRouteName="echo-route"

# Ingress and DNS
dnsZoneName="babosbird.com"
dnsZoneResourceGroupName="DnsResourceGroup"
subdomain="tanagfc"
hostname="$subdomain.$dnsZoneName"
