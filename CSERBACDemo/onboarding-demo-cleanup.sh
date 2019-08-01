#!/bin/bash

echo "**Logging in as System Admin**"
vcd login director.vcd.zpod.io system administrator -iw


echo "**Removing "{cse}:PKS DEPLOY RIGHT" right from enterprise-dev-org**"
vcd right remove "{cse}:PKS DEPLOY RIGHT" -o enterprise-dev-org


echo "**Ensure we are using the enterprise-dev-org**"
vcd org use enterprise-dev-org


echo "**Disabling k8 provider for ent-dev-ovdc**"
vcd cse ovdc disable ent-dev-ovdc

