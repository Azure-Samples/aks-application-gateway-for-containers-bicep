# Variables
source ./00-variables.sh

# Get the FQDN of the gateway
echo -n "Retrieving the FQDN of the [$gatewayName] gateway..."
while true
do
  fqdn=$(kubectl get gateway $gatewayName -n $namespace -o jsonpath='{.status.addresses[0].value}')
  if [[ -n $fqdn ]]; then
    echo 
    break 
  else
    echo -n '.'
    sleep 1
  fi
done

if [ -n $fqdn ]; then
  echo "[$fqdn] FQDN successfully retrieved from the [$gatewayName] gateway"
else
  echo "Failed to retrieve the FQDN from the [$gatewayName] gateway"
  exit
fi

# Check if an CNAME record for todolist subdomain exists in the DNS Zone
echo "Retrieving the CNAME for the [$subdomain] subdomain from the [$dnsZoneName] DNS zone..."
cname=$(az network dns record-set cname list \
  --zone-name $dnsZoneName \
  --resource-group $dnsZoneResourceGroupName \
  --query "[?name=='$subdomain'].CNAMERecord.cname" \
  --output tsv \
  --only-show-errors)

if [[ -n $cname ]]; then
  echo "A CNAME already exists in [$dnsZoneName] DNS zone for the [$subdomain]"

  if [[ $cname == $fqdn ]]; then
    echo "The [$cname] CNAME equals the FQDN of the [$gatewayName] gateway. No additional step is required."
    exit
  else
    echo "The [$cname] CNAME is different than the [$fqdn] FQDN of the [$gatewayName] gateway"
  fi

  # Delete the CNAME record
  echo "Deleting the [$subdomain] CNAME from the [$dnsZoneName] zone..."

  az network dns record-set cname delete \
    --name $subdomain \
    --zone-name $dnsZoneName \
    --resource-group $dnsZoneResourceGroupName \
    --only-show-errors \
    --yes

  if [[ $? == 0 ]]; then
    echo "[$subdomain] CNAME successfully deleted from the [$dnsZoneName] zone"
  else
    echo "Failed to delete the [$subdomain] CNAME from the [$dnsZoneName] zone"
    exit
  fi
else
  echo "No CNAME exists in [$dnsZoneName] DNS zone for the [$subdomain] subdomain"
fi

# Create a CNAME record
echo "Creating a CNAME in the [$dnsZoneName] DNS zone for the [$fqdn] FQDN of the [$gatewayName] gateway..."
az network dns record-set cname set-record \
  --cname $fqdn \
  --zone-name $dnsZoneName \
  --resource-group $dnsZoneResourceGroupName \
  --record-set-name $subdomain \
  --only-show-errors 1>/dev/null

if [[ $? == 0 ]]; then
  echo "[$subdomain] CNAME successfully created in the [$dnsZoneName] DNS zone for the [$fqdn] FQDN of the [$gatewayName] gateway"
else
  echo "Failed to create a CNAME in the [$dnsZoneName] DNS zone for the [$fqdn] FQDN of the [$gatewayName] gateway"
fi
