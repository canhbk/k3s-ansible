kubectl create namespace karmada-system
kubectl apply -f karmada-operator-clusterrole.yaml
kubectl apply -f karmada-operator-clusterrolebinding.yaml
kubectl apply -f karmada-operator-serviceaccount.yaml


kubectl apply -f karmada-operator-deployment.yaml