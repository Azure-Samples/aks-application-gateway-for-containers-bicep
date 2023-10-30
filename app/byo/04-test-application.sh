#!/bin/bash

# Variables
source ./00-variables.sh

# Curling this FQDN should return responses from the backend as configured in the HTTPRoute
curl https://$hostname

