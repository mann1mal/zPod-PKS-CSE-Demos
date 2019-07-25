## Kubernetes Network Policy and NSX-T DFW Integration

In this demo, we are going to walk through the process of using the Kubernetes construct of [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to ensure workloads running in our Kubernetes clusters are secured from a network perspective. For those unfamiliar with the Network Policy construct in the Kubernetes world, they are essentially "firewall" rules that can be applied to certain services or pods to restrict pod to pod communication as well as communication between the external network and pods in the Kubernetes cluster.

#### The NSX Container Plugin

As part of the integration between Enterprise PKS and NSX-T, the [NSX Container Plugin (NCP)](https://docs.vmware.com/en/VMware-NSX-T-Data-Center/2.4/com.vmware.nsxt.ncp_kubernetes.do) is responsible for reaching out to the NSX-T Manager API to create networking resources to correlate with the Kubernetes resources that are created by the developers via kubectl. For instance, back in our [second demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/GuestbookDemo), when we created a namespace to support our applications, the NCP instructed the NSX-T Manager to create a new /24 network and T1 router to support pods running in this new namespace.

Log in to the [NSX-T manager](https://nsx.pks.zpod.io) and navigate to the **Advanced Network and Security** tab. Select the **Switching** category if it isn't already selected. Type the UUID of the demo-cluster(`6e92c1a9-c8f2-4774-ba8b-7786e7fc8d50`) into the search bar and you will see the NSX-T logical switches created for each namespace in the cluster, including the `appspace` namespace. You can also navigate to the **Routers** tab, search on the cluster UUID and point out the T1 routers for each namespace:

![Screen Shot 2019-07-25 at 3 50 30 PM](https://user-images.githubusercontent.com/32826912/61904215-5ef6da00-aef4-11e9-8049-04159ad5e86d.png)

![Screen Shot 2019-07-25 at 3 51 05 PM](https://user-images.githubusercontent.com/32826912/61904220-63bb8e00-aef4-11e9-9b2c-06a4f6b62e75.png)

Among other things, the NCP also handles the creation of NSX-T Distributed Firewall Rules when developers create Network Policies in their kubernetes clusters. We will walk through this workflow in detail utilizing our Yelb app deployment in the demo below.

#### Network Policies and DFW Rules
