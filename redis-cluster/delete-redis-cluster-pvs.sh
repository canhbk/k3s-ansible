#!/bin/bash

# Delete PVs with claim name matching "redis-data-my-redis-redis-cluster-*"
for pv in $(kubectl get pv -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.claimRef.namespace}{" "}{.spec.claimRef.name}{"\n"}{end}' | grep '^pvc' | grep 'redis-data-my-redis-redis-cluster-' | awk '{print $1}')
do
  echo "Deleting PV: $pv"
  kubectl delete pv "$pv"
done
