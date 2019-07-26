# Guestbook Demo Workflow

The guestbook app demo helps demonstrate the usage of persistent storage, which is automated via the vSphere Cloud Provider, as well as the creation of NSX-T Load Balancer for external application access. We will also showcase the built-in ingress controller offered per cluster in NSX-T.

**Note:** Ensure that you are using your Horizon instance (access instruction detailed [here](https://confluence.eng.vmware.com/display/CPCSA/CSE+zPod+Lab+Access+and+Demo+Scripts)) to access the demo environment.

Before you start the demo, let's ensure we are accessing the `demo-cluster`:
~~~
$ vcd login director.vcd.zpod.io cse-demo-org cse-ent-user -iwp VMware1!
~~~
~~~
$ vcd cse cluster config demo-cluster > ~/.kube/config
~~~
~~~
$ kubectl get nodes
NAME                                   STATUS   ROLES    AGE     VERSION
0faf789a-18db-4b3f-a91a-a9e0b213f310   Ready    <none>   5d9h    v1.13.5
713d03dc-a5de-4c0f-bbfe-ed4a31044465   Ready    <none>   5d10h   v1.13.5
8aa79ec7-b484-4451-aea8-cb5cf2020ab0   Ready    <none>   5d10h   v1.13.5
~~~
Navigate to the `~/zPod-PKS-CSE-Demos/GuestbookDemo/` directory on the cse-client server:
~~~
$ cd ~/zPod-PKS-CSE-Demos/GuestbookDemo/
~~~
Before we create any workloads, let's create a namespace to host our applications and set our context to ensure we are deploying workloads into this new namespace by default:
~~~
$ kubectl create namespace appspace
~~~
~~~
$ kubectl config set-context --current --namespace=appspace
~~~
Use kubectl to deploy the storage class and persistent volume claim we will use to provide persistent storage to the guestbook app:
~~~
$ kubectl create -f redis-master-claim.yaml
$ kubectl create -f redis-slave-claim.yaml
$ kubectl create -f redis-sc.yaml
~~~

View the storage resources we just created:
~~~
$ kubectl get sc
$ kubectl describe sc thin-disk
$ kubectl get pvc
$ kubectl get pv
~~~
This would be a good time to talk about persistent storage in kubernetes clusters and the integration with the VMware SDDC that is provided by the vSphere Cloud Provider. 

Log in to the PKS vcsa (vcsa.pks.zpod.io), navigate to the "NFS-02" datastore and select the "kubevols" folder. The VMDKs, which are persistent volumes in the kubernetes world, were automatically created by the vSphere Cloud Provider when we created our persistent volume claims. We can correlate the VMDK with the PVs as the name is the same for both resources.

![Screen Shot 2019-07-02 at 9 08 06 AM](https://user-images.githubusercontent.com/32826912/61248174-8e515e00-a720-11e9-92d0-870bc566345e.png)

![Screen Shot 2019-07-02 at 9 08 46 AM](https://user-images.githubusercontent.com/32826912/61248204-9d381080-a720-11e9-8c18-15f41296829e.png)


Create the components of the guestbook app and watch for the pods to be created:
~~~
$ kubectl create -f guestbook-aio.yaml
$ kubectl get pods -o wide -w
~~~
List the services we created for the guestbook app and take note of the 10.96.59.X IP address for the LoadBalancer service. We will use this IP to access the guestbook app in the browser:
~~~
$ kubectl get services
~~~
Before (or after) you access the app via the IP of the LoadBalancer service, log into the [NSX-T manager](https://nsx.pks.zpod.io) and navigate to the "Advanced Network and Security" tab. Within the "Networking" category, select the "Load Balancers" option. Find your LB instance and locate the virtual server with the "-default-fronted" suffix, note the IP address (same as LoadBalancer service)

![Screen Shot 2019-07-02 at 9 13 10 AM](https://user-images.githubusercontent.com/32826912/61248270-ba6cdf00-a720-11e9-9e1d-08884c7ab78b.png)

![Screen Shot 2019-07-02 at 9 12 42 AM](https://user-images.githubusercontent.com/32826912/61248298-c8226480-a720-11e9-9177-564222c14084.png)

Navigate to the "Server Pools" tab and select the same "-default-frontend" LB. Select "Member Pools" in the menu on the right side of the UI that expands once the LB is selected. Compare IPs to the output of the following command on the CLI:

![Screen Shot 2019-07-02 at 9 14 37 AM](https://user-images.githubusercontent.com/32826912/61248333-db353480-a720-11e9-888e-74b6c9f5a6bf.png)

~~~
$ kubectl get pods -l tier=frontend -o wide
~~~

![Screen Shot 2019-07-02 at 9 14 01 AM](https://user-images.githubusercontent.com/32826912/61248375-eee09b00-a720-11e9-957f-2564253fcba6.png)

All of this automation is made possible by the NSX-T Container Plugin.

If you haven't already, navigate to the homepage of the GuestBook app (IP of the LoadBalancer service from step 5.) and enter a couple of entries. We will then delete the backend database and cache.
~~~
$ kubectl get pod -l tier=frontend
$ kubectl get pod -l tier=backend
$ kubectl delete pod -l tier=backend
$ kubectl get pod -w
~~~
The redis master and slave pods will be automatically created because they are part of a kubernetes deployment, which ensures there is always at least X number of instance of these pods running (in our case, X=1). Wait for the pods to return to the "Started" state and refresh the webpage to ensure the previous guestbook entries are still present.

Let's scale our frontend pods to 5 instead of 3 and monitor what happens in NSX-T:
~~~
$ kubectl get deployments
$ kubectl scale deployments frontend --replicas=5
$ kubectl get pods -l tier=frontend
~~~
Now we should have 5 pods for the frontend deployment, up from 3. If we look in the NSX-T manager, we should observe that the additional two pods were automatically added to the server pool of the Load Balancer (ignore IP changes from previous example, utilized different cluster for this exercise). The NCP automates this entire process so there is no manually intervention needed to distribute traffic to newly created pods.

<img width="1374" alt="Screen Shot 2019-07-08 at 9 21 21 PM" src="https://user-images.githubusercontent.com/32826912/61248428-0a4ba600-a721-11e9-885c-ee00fba2b275.png">

<img width="1194" alt="Screen Shot 2019-07-08 at 9 22 11 PM" src="https://user-images.githubusercontent.com/32826912/61248463-1cc5df80-a721-11e9-855a-c7bba203405d.png">

Scale the frontend pods back down to 3 (observe the Pool Members again in NSX-T if you'd like):
~~~
$ kubectl scale deployments frontend --replicas=3
~~~
Proceed to the [next demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/Ingress%26NSX-T) to showcase how to configure the ingress controller provided by NSX-T to front multiple apps running in a PKS Kubernetes cluster.
