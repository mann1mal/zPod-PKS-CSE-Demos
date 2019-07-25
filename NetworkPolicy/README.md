# Kubernetes Network Policy and NSX-T DFW Integration

In this demo, we are going to walk through the process of using the Kubernetes construct of [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to ensure workloads running in our Kubernetes clusters are secured from a network perspective. For those unfamiliar with the Network Policy construct in the Kubernetes world, they are essentially "firewall" rules that can be applied to certain services or pods to restrict pod to pod communication as well as communication between the external network and pods in the Kubernetes cluster.

## The NSX Container Plugin

As part of the integration between Enterprise PKS and NSX-T, the [NSX Container Plugin (NCP)](https://docs.vmware.com/en/VMware-NSX-T-Data-Center/2.4/com.vmware.nsxt.ncp_kubernetes.do) is responsible for reaching out to the NSX-T Manager API to create networking resources to correlate with the Kubernetes resources that are created by the developers via kubectl. For instance, back in our [second demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/GuestbookDemo), when we created a namespace to support our applications, the NCP instructed the NSX-T Manager to create a new /24 network and T1 router to support pods running in this new namespace.

Log in to the [NSX-T manager](https://nsx.pks.zpod.io) and navigate to the **Advanced Network and Security** tab. Select the **Switching** category if it isn't already selected. Type the UUID of the demo-cluster(`6e92c1a9-c8f2-4774-ba8b-7786e7fc8d50`) into the search bar and you will see the NSX-T logical switches created for each namespace in the cluster, including the `appspace` namespace. You can also navigate to the **Routers** tab, search on the cluster UUID and point out the T1 routers for each namespace:

![Screen Shot 2019-07-25 at 3 50 30 PM](https://user-images.githubusercontent.com/32826912/61904215-5ef6da00-aef4-11e9-8049-04159ad5e86d.png)

![Screen Shot 2019-07-25 at 3 51 05 PM](https://user-images.githubusercontent.com/32826912/61904220-63bb8e00-aef4-11e9-9b2c-06a4f6b62e75.png)

Among other things, the NCP also handles the creation of NSX-T Distributed Firewall Rules when developers create Network Policies in their kubernetes clusters to help extend the level of microsegmentation available to "traditional" compute resources into the kubernetes world. We will walk through this workflow in detail utilizing our Yelb app deployment in the demo below.

## Network Policies and DFW Rules

First thing's first, let's ensure we are operating in the correct namespace. Also, if you did not deploy the Yelb app from the previous demos, please deploy it now as well:
~~~
$ kubectl config set-context --current --namespace=appspace
~~~
~~~
$ kubectl create -f yelb-ingress.yaml
~~~
Let's test connectivity to the Yelb UI at `yelb.demo.pks.zpod.io` to confirm the app deployed succesfully:

![Screen Shot 2019-07-23 at 2 54 57 PM](https://user-images.githubusercontent.com/32826912/61739173-eb20ca00-ad59-11e9-9a76-6af44e8476bf.png)

In a Kubernetes cluster, if there is no Network Policy defined, Kubernetes allows all communication: all pods can talk to each-other freely. This may work in some cases, especially in dev environment, but teams can use Network Policies to further restrict network communication between services in a Kubernetes cluster, if required.

The first thing we will do is create a policy that will deny all ingress access to the pods in the appspace namespace, from within and without the cluster. Navigate to the `~/zPod-PKS-CSE-Demos/NetworkPolicy` directory and create the deny all policy:
~~~
$ cd ~/zPod-PKS-CSE-Demos/NetworkPolicy
~~~
~~~
$ kubectl create -f appspace-deny-all.yaml
~~~
So let's take a look at what's happened in the NSX-T manager...

Navigate back to the NSX-T Manager webUI, select the **Advanced Network and Security** tab and then the **Security** > **Distrubuted Firewall Rule** tab on the left hand menu. Locate the `ip-pks-6e92c1a9-c8f2-4774-ba8b-7786e7fc8d50` firewall rule and expand the selection

![Screen Shot 2019-07-25 at 4 16 39 PM](https://user-images.githubusercontent.com/32826912/61905732-cbbfa380-aef7-11e9-97dc-0b587eb08213.png)

Here we can see the NCP reached out to the NSX-T Manager to create a DFW rule to drop traffic from source `Any` to a target port group. If we click on the target port group, we can see this group is defined from a /24 network:

![Screen Shot 2019-07-25 at 4 19 59 PM](https://user-images.githubusercontent.com/32826912/61905851-13dec600-aef8-11e9-9524-86f7ddd1308f.png)

Navigate back to the CLI and examine the IP addresses of the pods providing the Yelb app:
~~~
$ kubectl get pods -o wide
NAME                              READY   STATUS    RESTARTS   AGE   IP 
redis-server-86f48f4875-5kf62     1/1     Running   0          15m   172.16.19.3   
yelb-appserver-66b579569f-hrfzf   1/1     Running   0          15m   172.16.19.5   
yelb-db-76c6f5d6fb-nj4fc          1/1     Running   0          15m   172.16.19.4   
yelb-ui-dcb8746fb-xf9g6           1/1     Running   0          15m   172.16.19.2   
~~~
The 172.16.19.0/24 network was created (by the NCP) automatically to be utilize by pods in the `appspace` namespace.

Now that we confirmed we have blocked all traffic to all pods in the namespace, let's try to access the Yelb UI again. As expected, we can not access the webUI because our DFW rule is not allowing any traffic to reach the pods in the cluster. As a side note, the app itself is not functional as the deny-all network policy we have in place is not allowing the components of the app to communicate with each other.


