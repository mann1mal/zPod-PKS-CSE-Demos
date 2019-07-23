# Ingress Controller and NSX-T

As you may remember from our [first demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/blob/master/GuestbookDemo/README.md), if we use the kubernetes service type of `LoadBalancer` to expose an app to external connections in a PKS cluster, we would still need to manually add DNS records for each NSX-T Load Balancer IP created so that external connections could resolve on a hostname. 

If we use a service type of `Ingress` instead, in conjunction with a DNS wildcard record, we can manage hostname resolution directly at the kubernetes layer via the Ingress controller (NSX-T layer 7 load balancer) that is automatically deployed in NSX-T upon cluster creation. This allows developers to fully manager the hostnames that resolve to multiple apps without having to create DNS records for each service they are looking to expose externally.

**Note:** Ensure that you are using your Horizon instance (access instruction detailed [here](https://confluence.eng.vmware.com/display/CPCSA/CSE+zPod+Lab+Access+and+Demo+Scripts)) to access the demo environment.

## Configure Ingress Service for Guestbook App

After performing the [first demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/blob/master/GuestbookDemo/README.md), you'll need to change the `frontend` service from `LoadBalancer` type to `ClusterIP` type by editing the service via kubectl and making the changes notated below to the spec section (Note: your ClusterIP may be different than the one in the screenshot and that's ok):
~~~
$ kubectl edit svc frontend
~~~

<img width="514" alt="Screen Shot 2019-07-10 at 10 28 59 AM" src="https://user-images.githubusercontent.com/32826912/61248498-2d765580-a721-11e9-8a09-87601e39ac8b.png">

Verify the "frontend" service is now type "ClusterIP"
~~~
$ kubectl get svc
~~~
**Note:** Because we changed the "frontend" service to `ClusterIP` type, note that the NSX-T load balancer from Demo 1 has been deleted from the NSX-T manager automatically.

Now we are ready to create our ingress service to expose the guestbook app via FQDN. In the lab environment, we have set up a DNS wildcard that resolves "*.app.pks.zpod.io" to the IP address of the NSX-T load balancer that is automatically created by PKS to serve as the ingress controller.

Navigate to the `~/zPod-PKS-CSE-Demos/Ingress\&NSX-T/` directory on the cse-client server:
~~~
$ cd ~/zPod-PKS-CSE-Demos/Ingress\&NSX-T/
~~~

Review the frontend-ingress.yaml file and note the `host:` entry. This is the hostname (guestbook.app.pks.zpod.io) the ingress controller will redirect to the service offering up the Web UI(frontend service) for our guestbook portal. Create the ingress controller from the frontend-ingress.yaml file in the guestbook directory and verify the hostname of the app is accessible via the Web UI:
~~~
$ kubectl create -f frontend-ingress.yaml 
$ kubectl get ingress
~~~
Navigate to the URL displayed in the output of the above command to verify connectivity:

<img width="827" alt="Screen Shot 2019-07-10 at 11 19 43 AM" src="https://user-images.githubusercontent.com/32826912/61248575-5f87b780-a721-11e9-870f-9761277a5690.png">

## Adding a Second App
