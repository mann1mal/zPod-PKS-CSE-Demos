# Guestbook Demo Workflow

The guestbook app demo helps demonstrate the usage of persistent storage, which is automated via the vSphere Cloud Provider, as well as the creation of NSX-T Load Balancer for external application access. We will also showcase the built-in ingress controller offered per cluster in NSX-T.

Navigate to the "demofiles/guestbook" directory on the cse-client server:
~~~
$ cd ~/demofiles/guestbook
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
Before (or after) you access the app via the IP of the LoadBalancer service, log into the NSX-T manager (https://nsx.pks.zpod.io) and navigate to the "Advanced Network and Security" tab. Within the "Networking" category, select the "Load Balancers" option. Find your LB instance and locate the virtual server with the "-default-fronted" suffix, note the IP address (same as LoadBalancer service)

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

# Change LoadBalancer to Ingress Controller

As you may notice, if we use the service type of "LoadBalancer" to expose an app to external connections, we would still need to manually add DNS records for each NSX-T Load Balancer IP created so that external connections could resolve on a hostname. If we use a service type of "Ingress" instead, in conjunction with a DNS wildcard record, we can manage hostname resolution directly from the kubernetes cluster via the Ingress controller that is automatically deployed in NSX-T on cluster creation.

Change the "frontend" service from "LoadBalancer" type to "ClusterIP" type by editing the service via kubectl and making the changes notated below to the spec section (Note: your ClusterIP may be different than the one in the screenshot and that's ok):
~~~
$ kubectl edit svc frontend
~~~

<img width="514" alt="Screen Shot 2019-07-10 at 10 28 59 AM" src="https://user-images.githubusercontent.com/32826912/61248498-2d765580-a721-11e9-8a09-87601e39ac8b.png">

Verify the "frontend" service is now type "ClusterIP"
~~~
$ kubectl get svc
~~~
Now we are ready to create our ingress service to expose the guestbook app via FQDN. In the lab environment, we have set up a DNS wildcard that resolves "*.app.pks.zpod.io" to the IP address of the NSX-T load balancer that is automatically created by PKS to serve as an ingress controller (per cluster). This allows our developers to deploy new apps and use the ingress service type in kubernetes to define DNS hostnames that can resolve to the IP of the NSX-T load balancer that is serving as the ingress controller instead of having to update DNS records for each of our apps exposed to the external net. 

Review the frontend-ingress.yaml file and note the "host:" entry. This is the hostname (guestbook.app.pks.zpod.io) the ingress controller will redirect to the service offering up the Web UI for our guestbook portal. Create the ingress controller from the frontend-ingress.yaml file in the guestbook directory and verify the hostname of the app is accessible via the Web UI:
~~~
$ kubectl create -f frontend-ingress.yaml 
$ kubectl get ingress
~~~
Navigate to the URL displayed in the output of the above command to verify connectivity:

<img width="827" alt="Screen Shot 2019-07-10 at 11 19 43 AM" src="https://user-images.githubusercontent.com/32826912/61248575-5f87b780-a721-11e9-870f-9761277a5690.png">

Taadaa!!


