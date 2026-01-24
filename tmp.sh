for ns in $(kubectl get ns --no-headers | awk '/Terminating/ {print $1}'); do
  echo "🔧 Force cleaning namespace: $ns"

  kubectl get ns "$ns" -o json \
    | jq 'del(.spec.finalizers) | del(.metadata.finalizers)' \
    | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
done
