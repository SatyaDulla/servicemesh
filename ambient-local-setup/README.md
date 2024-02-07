# ambient-local-setup-demo
Setting up local ambient mesh using kind

# Prerequisites
1. [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
2. [Docker](https://docs.docker.com/desktop/install/mac-install/)
3. [direnv](https://direnv.net/) - Makes life easier
4. [jq](https://stedolan.github.io/jq/download/)
5. kubectl

## kind installation
```sh
brew install kind
```

## docker installation
Follow the [Docker guide](https://docs.docker.com/desktop/install/mac-install/) for the installation

# Ambient Mesh set up using `Kind`

1. Clone and cd to the repo
```sh
git clone git@github.csnzoo.com:sdulla/ambient-local-setup-demo.git; cd ambient-local-setup-demo;
```

2. Create and verify Kind cluster
  ```sh
 sh -x create_kind_cluster.sh
  ```

  ```
kubectl cluster-info --context kind-ambient-lab
  ```

3. Install Kubernetes Gateway CRDs
  ```sh
  sh -x install_k8s_gw_crds.sh
  ```

4. Download the latest version of Istio with alpha support for ambient mesh

```
sh -x download_unpack_istioctl.sh
```

4. Ambient profile installation

Make sure you're in the right directory and set the env variables to use istioctl binary and istioctl CLI from the downloaded package.

```
istioctl install --set profile=ambient --skip-confirmation
```

output should look similar to this
```output
✔ Istio core installed
✔ Istiod installed
✔ Ztunnel installed
✔ Ingress gateways installed
✔ CNI installed
✔ Installation
complete
```

Note: It should add CNI plugin, Ztunnel per node upon successful installation

verify the installed components using the following commands
```sh
kubectl get pods -o wide -n istio-system
```
and istio cni and ztunnel pod are added from daemonset
```sh
kubectl get daemonset -n istio-system
```

# Deploying demo sample applications

Installs bookinfo, sleep, nonsleep apps
```sh
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/sleep/sleep.yaml
kubectl apply -f samples/sleep/notsleep.yaml
```

# Adding application to Ambient

`kubectl label namespace default istio.io/dataplane-mode=ambient`

# Misc

## Making a request
```sh
kubectl exec deploy/sleep -- curl -s http://productpage:9080/ | grep -o "<title>.*</title>"
```

## Collecting the config dump
`kubectl exec -it ztunnel-9q589 -n istio-system -- curl localhost:15000/config_dump | jq .`

### Sample config dump for a workload when `ambient` is enabled for a namespace
`"protocol": "HBONE"`
```jq
    "10.244.1.9": {
      "workloadIp": "10.244.1.9",
      "waypointAddresses": [],
      "gatewayAddress": null,
      "protocol": "HBONE",
      "name": "productpage-v1-58b4c9bff8-slbgg",
      "namespace": "default",
      "serviceAccount": "bookinfo-productpage",
      "workloadName": "productpage-v1",
      "workloadType": "deployment",
      "canonicalName": "productpage",
      "canonicalRevision": "v1",
      "node": "ambient-lab-worker",
      "nativeHbone": false,
      "authorizationPolicies": [],
      "status": "Healthy"
    }
```

### config dump for a workload when `ambient` is disabled for a namespace
`"protocol": "TCP"`
```jq
    "10.244.1.9": {
      "workloadIp": "10.244.1.9",
      "waypointAddresses": [],
      "gatewayAddress": null,
      "protocol": "TCP",
      "name": "productpage-v1-58b4c9bff8-slbgg",
      "namespace": "default",
      "serviceAccount": "bookinfo-productpage",
      "workloadName": "productpage-v1",
      "workloadType": "deployment",
      "canonicalName": "productpage",
      "canonicalRevision": "v1",
      "node": "ambient-lab-worker",
      "nativeHbone": false,
      "authorizationPolicies": [],
      "status": "Healthy"
    }
```

## Listing workloads
`istioctl pc workload ztunnel-9q589.istio-system`

sample output -- Workloads injected with `ambient` label with PROTOCOL `HBONE`
```bash
NAME                                    NAMESPACE          IP         NODE                      L7 SUPPORT PROTOCOL
coredns-787d4945fb-5d4hm                kube-system        10.244.0.3 ambient-lab-control-plane false      TCP
coredns-787d4945fb-tbgm7                kube-system        10.244.0.2 ambient-lab-control-plane false      TCP
details-v1-6997d94bb9-vb6g5             default            10.244.1.4 ambient-lab-worker        false      HBONE
istio-ingressgateway-5b9bdc9d4f-hgs9z   istio-system       10.244.1.2 ambient-lab-worker        false      TCP
istiod-6f876b7cdc-s2xwj                 istio-system       10.244.2.2 ambient-lab-worker2       false      TCP
local-path-provisioner-75f5b54ffd-h44xw local-path-storage 10.244.0.4 ambient-lab-control-plane false      TCP
notsleep-5fb85fb789-th7kc               default            10.244.2.5 ambient-lab-worker2       false      HBONE
productpage-v1-58b4c9bff8-slbgg         default            10.244.1.9 ambient-lab-worker        false      HBONE
ratings-v1-b8f8fcf49-2lmtd              default            10.244.1.5 ambient-lab-worker        false      HBONE
reviews-v1-5896f547f5-rrrwf             default            10.244.1.7 ambient-lab-worker        false      HBONE
reviews-v2-5d99885bc9-fvkft             default            10.244.1.8 ambient-lab-worker        false      HBONE
reviews-v3-589cb4d56c-wq5mq             default            10.244.1.6 ambient-lab-worker        false      HBONE
sleep-bc9998558-p8g86                   default            10.244.2.4 ambient-lab-worker2       false      HBONE
ztunnel-b8w5q                           istio-system       10.244.0.5 ambient-lab-control-plane false      TCP
ztunnel-gclxc                           istio-system       10.244.1.3 ambient-lab-worker        false      TCP
ztunnel-gkpts                           istio-system       10.244.2.3 ambient-lab-worker2       false      TCP
```

## sample ztunnel log

`│ 25.369615Z  INFO inbound{id=fb806b094637e6784677548a9c3c9a58 peer_ip=10.244.2.4 peer_id=spiffe://cluster.local/ns/default/sa/sleep}: ztunnel::proxy::inbound: got CONNECT request to 10.244.1.9:9080`

## cni plugin logs

### When enabling `ambient` label for a namespace
`Adding pod 'details-v1-6997d94bb9-vb6g5/default' (a7ed8669-6c60-47a2-8dcf-b5529cabdf38) to ipset`

```
2023-05-08T22:10:57.770899Z    info    ambient    Namespace default is enabled in ambient mesh                                                                                                       │
│ 2023-05-08T22:10:57.772712Z    info    ambient    Adding pod 'details-v1-6997d94bb9-vb6g5/default' (a7ed8669-6c60-47a2-8dcf-b5529cabdf38) to ipset                                                   │
│ 2023-05-08T22:10:57.790434Z    info    ambient    Adding route for details-v1-6997d94bb9-vb6g5/default: [table 100 10.244.1.4/32 via 192.168.126.2 dev istioin src 10.244.1.1]                       │
│ 2023-05-08T22:10:57.820093Z    info    ambient    Adding pod 'ratings-v1-b8f8fcf49-2lmtd/default' (c01fbf36-a6f0-4957-8594-c6b02a5de037) to ipset                                                    │
│ 2023-05-08T22:10:57.847808Z    info    ambient    Adding route for ratings-v1-b8f8fcf49-2lmtd/default: [table 100 10.244.1.5/32 via 192.168.126.2 dev istioin src 10.244.1.1]                        │
│ 2023-05-08T22:10:57.886796Z    info    ambient    Adding pod 'reviews-v1-5896f547f5-rrrwf/default' (88c369fd-dedc-4b15-baa2-ad31c246bbe6) to ipset                                                   │
│ 2023-05-08T22:10:57.903443Z    info    ambient    Adding route for reviews-v1-5896f547f5-rrrwf/default: [table 100 10.244.1.7/32 via 192.168.126.2 dev istioin src 10.244.1.1]                       │
│ 2023-05-08T22:10:57.942382Z    info    ambient    Adding pod 'reviews-v2-5d99885bc9-fvkft/default' (1b589389-c27c-49ea-a91b-fd871436e379) to ipset                                                   │
│ 2023-05-08T22:10:57.955413Z    info    ambient    Adding route for reviews-v2-5d99885bc9-fvkft/default: [table 100 10.244.1.8/32 via 192.168.126.2 dev istioin src 10.244.1.1]
```

### when disable `ambient` label for a namespace
`Removing pod 'reviews-v2-5d99885bc9-fvkft' (1b589389-c27c-49ea-a91b-fd871436e379) from ipset`

```
2023-05-08T22:13:18.496692Z    info    ambient    Namespace default is disabled from ambient mesh                                                                                                    │
│ 2023-05-08T22:13:18.497120Z    info    ambient    Pod default/reviews-v2-5d99885bc9-fvkft is now stopped... cleaning up.    type=delete                                                              │
│ 2023-05-08T22:13:18.497423Z    info    ambient    Removing pod 'reviews-v2-5d99885bc9-fvkft' (1b589389-c27c-49ea-a91b-fd871436e379) from ipset                                                       │
│ 2023-05-08T22:13:18.512158Z    info    ambient    Removing route: [table 100 10.244.1.8/32 via 192.168.126.2 dev istioin src 10.244.1.1]                                                             │
│ 2023-05-08T22:13:18.539061Z    info    ambient    Pod default/reviews-v3-589cb4d56c-wq5mq is now stopped... cleaning up.    type=delete                                                              │
│ 2023-05-08T22:13:18.539674Z    info    ambient    Removing pod 'reviews-v3-589cb4d56c-wq5mq' (9ea1c657-8bf5-4bde-a030-db57a597283d) from ipset                                                       │
│ 2023-05-08T22:13:18.562273Z    info    ambient    Removing route: [table 100 10.244.1.6/32 via 192.168.126.2 dev istioin src 10.244.1.1]                                                             │
│ 2023-05-08T22:13:18.618828Z    info    ambient    Pod default/productpage-v1-58b4c9bff8-slbgg is now stopped... cleaning up.    type=delete                                                          │
│ 2023-05-08T22:13:18.619107Z    info    ambient    Removing pod 'productpage-v1-58b4c9bff8-slbgg' (7ea211db-586b-45a3-969b-001964cab94e) from ipset
```

## Debigging network traffic using netshoot
`k debug -it ztunnel-ldf45 --image=nicolaka/netshoot --image-pull-policy=Always`

`termshark -i eth0`

## Updating logs on ztunnel pods
` kubectl exec -it ztunnel-ldf45 -n istio-system -- curl -X POST 'http://127.0.0.1:15000/logging?level=info'`
` kubectl exec -it ztunnel-ldf45 -n istio-system -- curl -X POST 'http://127.0.0.1:15000/logging?level=debug'`

## Deleting cluster
```sh
kind delete clusters ambient-lab
```

## References
- https://istio.io/latest/blog/2022/introducing-ambient-mesh/ - Sep 2022 (Initial release)
- https://www.youtube.com/watch?v=2kOZ4rnYI4g - Kubecon Sep 2022 (Initial release)
- https://istio.io/latest/blog/2023/ambient-merged-istio-main/ - Feb 2023
- https://istio.io/latest/blog/2023/rust-based-ztunnel/ - Feb 2023
- https://istio.io/latest/blog/2023/waypoint-proxy-made-simple/ - March 2023
- https://www.solo.io/products/ambient-mesh/
- https://github.com/istio/istio
- https://github.com/istio/ztunnel
- https://preliminary.istio.io/latest/docs/ops/ambient/getting-started/
