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
