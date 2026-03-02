#!/bin/bash
set -e

RG="rg-volingo-prod"
ZONE="haibaoenglishlearning.com"

echo "=== Adding Domain Verification TXT ==="
az network dns record-set txt add-record -g $RG -z $ZONE -n "@" -v "ms-domain-verification=9c9f9fa8-a26d-4e33-9098-a0b7f99d62bf" -o none
echo "Done"

echo "=== Adding SPF TXT ==="
az network dns record-set txt add-record -g $RG -z $ZONE -n "@" -v "v=spf1 include:spf.protection.outlook.com -all" -o none
echo "Done"

echo "=== Adding DKIM1 CNAME ==="
az network dns record-set cname create -g $RG -z $ZONE -n "selector1-azurecomm-prod-net._domainkey" --ttl 3600 -o none 2>/dev/null || true
az network dns record-set cname set-record -g $RG -z $ZONE -n "selector1-azurecomm-prod-net._domainkey" -c "selector1-azurecomm-prod-net._domainkey.azurecomm.net" -o none
echo "Done"

echo "=== Adding DKIM2 CNAME ==="
az network dns record-set cname create -g $RG -z $ZONE -n "selector2-azurecomm-prod-net._domainkey" --ttl 3600 -o none 2>/dev/null || true
az network dns record-set cname set-record -g $RG -z $ZONE -n "selector2-azurecomm-prod-net._domainkey" -c "selector2-azurecomm-prod-net._domainkey.azurecomm.net" -o none
echo "Done"

echo "=== All DNS records added! ==="
