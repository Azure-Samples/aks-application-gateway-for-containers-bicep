# Certificate Manager
cmNamespace="cert-manager"
cmRepoName="jetstack"
cmRepoUrl="https://charts.jetstack.io"
cmChartName="cert-manager"
cmReleaseName="cert-manager"
cmVersion="v1.14.0"

# Application Load Balancer 
applicationLoadBalancerName="alb"
applicationLoadBalancerNamespace="alb-infra"

# Demo
namespace="agc-demo"
gatewayName="echo-gateway"
issuerName="letsencrypt"
httpRouteName="echo-route"

# Ingress and DNS
dnsZoneName="babosbird.com"
dnsZoneResourceGroupName="DnsResourceGroup"
subdomain="shogunagc"
hostname="$subdomain.$dnsZoneName"
