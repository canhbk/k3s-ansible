# MySQL cluster setup

## Install Operator

helm repo add mysql-operator <https://mysql.github.io/mysql-operator/>
helm repo update

helm install my-mysql-operator mysql-operator/mysql-operator \
   --namespace mysql-**operator** --create-namespace

## Install MySQL Cluster

helm install mycluster mysql-operator/mysql-innodbcluster \
   --set tls.useSelfSigned=true --values values.yaml \
   --namespace mysql-cluster --create-namespace
