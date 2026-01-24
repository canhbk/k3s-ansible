 helm repo add karmada-charts <https://raw.githubusercontent.com/karmada-io/karmada/master/charts>

With the repo added, available charts and versions can be viewed.

```
helm search repo karmada
```

Install the chart and specify the version to install with the --version argument. Replace <x.x.x> with your desired version.

```
helm --namespace karmada-system upgrade -i karmada karmada-charts/karmada --version=1.14.0 --create-namespace
```

helm upgrade -i karmada-operator -n karmada-system --create-namespace --dependency-update karmada-charts/karmada-operator --set operator.image.tag=v1.13.5 --debug
