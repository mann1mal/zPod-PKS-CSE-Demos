# Using MetalLB and Contour in CSE Standard Clusters


### Accessing `ubuntu-cluster-1`

Before starting the demo, access the `cse-client` server with the `cse` user (`cse@cse-client.vcd.zpod.io`) from your Horizon instance via putty (pw is `VMware1!`):

<img src="Images/putty-ss.png">

In the past labs, we have been utilizing a Enterprise PKS-managed Kubernetes cluster. For this lab, we are going to switch to CSE Standard cluster. Ensure you are accessing `ubuntu-cluster-1` via kubectl by using the `cse` CLI extension to pull down the cluster config file and store it in the default location. Use the `cse-ent-user` with password `VMware1!` to log in to the `vcd-cli`:

~~~
$ vcd login director.vcd.zpod.io cse-demo-org cse-ent-user -iw
~~~
~~~
$ vcd cse cluster list

name              vdc                 status            org_name        k8s_version  k8s_provider
----------------  ------------------  ----------------  ------------  -------------  --------------
photon-cluster-1  standard-demo-ovdc  POWERED_ON        cse-demo-org           1.12  native
ubuntu-cluster-1  standard-demo-ovdc  POWERED_ON        cse-demo-org           1.15  native
demo-cluster      ent-demo-ovdc       create succeeded  cse-demo-org                 ent-pks
~~~
~~~
$ vcd cse cluster config ubuntu-cluster-1 > ~/.kube/config
~~~
~~~
$ kubectl get nodes
NAME        STATUS   ROLES    AGE   VERSION
mstr-gzhz   Ready    master   11d   v1.15.3
node-l6vu   Ready    <none>   11d   v1.15.3
node-lwdp   Ready    <none>   11d   v1.15.3
~~~
## Deploying MetalLB
~~~
$ cd ~/zPod-PKS-CSE-Demos/MetalLBandContour/
~~~
~~~
$ kubectl create -f metallb-deploy.yaml
~~~
~~~
$ kubectl get namespace
NAME              STATUS   AGE
default           Active   11d
kube-node-lease   Active   11d
kube-public       Active   11d
kube-system       Active   11d
metallb-system    Active   6d
~~~
~~~
$ kubectl get pods -n metallb-system
~~~
~~~
$ cat metallb-configmap.yaml 

apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 10.96.66.180-10.96.66.200
~~~
~~~
$ kubectl create -f nginx-app.yaml 
~~~
~~~
$ kubectl expose deploy nginx-app --target-port=80 --port=80 --type=LoadBalancer
~~~
Navigate to URL in webpage

## Deploying Contour

~~~
$ kubectl create -f contour.yaml 
~~~
~~~
$ kubectl get all -n heptio-contour

NAME                           READY   STATUS    RESTARTS   AGE
pod/contour-5c67c7cf7d-6xqkb   2/2     Running   0          115s
pod/contour-5c67c7cf7d-hxd7c   2/2     Running   0          115s

NAME              TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                      AGE
service/contour   LoadBalancer   10.102.44.251   10.96.66.181   80:31074/TCP,443:30315/TCP   115s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/contour   2/2     2            2           115s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/contour-5c67c7cf7d   2         2         2       115s
~~~

