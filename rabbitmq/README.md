helm install rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq  --values values.yaml \
--namespace rabbitmq --create-namespace

helm upgrade rabbitmq oci://registry-1.docker.io/bitnamicharts/rabbitmq  --values values.yaml \
--namespace rabbitmq --create-namespace
