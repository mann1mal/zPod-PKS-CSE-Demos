# Namespace Isolation with Network Policies and NSX-T

As was pointed out in our [first demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/CSERBACDemo), the Container Service Exstension automatically provisions NSX-T Distributed Firewall rules to ensure that each clusters' workloads are isolated from other clusters' workloads. But what if you'd like to share a single cluster with multiple users/groups instead of provision a dedicated cluster for each group?

One option is to utilize Network Policies to ensure network traffic can not traverse [namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) within a cluster. In one of our previous demos, we created the `appspace` namespace to house our applications. We're now going to onboard a new team that will deploy their applications to the `newspace` namespace. We'll also ensure pods from each namespace can't communicate with each other.

As detailed in the [previous demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/NetworkPolicy) Enterprise PKS Kubernetes clusters using NSX-T as the Container Network Interface (CNI) will have DFW rules automatically created in NSX-T when we create Network Policies. We will showcase this functionality again in this demo to isolate namespace network traffic.

## Testing Default Kubernetes Pod-to-Pod Network Connectivity
Before starting the demo, access the `cse-client` server from your Horizon instance via putty (pw is `VMware1!`) if you haven't already:

<img width="542" alt="Screen Shot 2019-08-02 at 8 30 20 PM" src="https://user-images.githubusercontent.com/32826912/62404702-6ce7d300-b564-11e9-8cce-145289c1e5e9.png">

Also, let's ensure we are accessing the `demo-cluster` via kubectl by using `cse` to pull down the cluster config file and store it in the default location. Use your vmc.lab AD credentials to log in to the `vcd-cli`:
~~~
$ vcd login director.vcd.zpod.io cse-demo-org <username> -iw
~~~
~~~
$ vcd cse cluster config demo-cluster > ~/.kube/config
~~~
Let's create our new namespace for our new team of developers:
~~~
$ kubectl create namespace newspace
~~~
Also, if you haven't done the previous labs, create the `appspace` namespace as well:
~~~
$ kubectl create namespace appspace
~~~
Let's create some apps we can use to test our policies in each namespace. We are going to deploy a nginx application in each namespace and instruct Kubernetes to serve out the nginx homepage on port 80 within the cluster. We're also going to label each pod:
~~~
$ kubectl run appspace-web --restart=Never --namespace appspace --image=nginx --labels=app=appspace-web --expose --port 80
$ kubectl run newspace-web --restart=Never --namespace newspace --image=nginx --labels=app=newspace-web --expose --port 80
~~~
Now before we set any network policies up, let's test whether or not the two pods can communicate with each other. 

Let's get the name and IP address of each pod:
~~~
$ kubectl get pods -n appspace-web -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP      
appspace-web   1/1     Running   0          2m58s   172.16.19.2
~~~
~~~
$ kubectl get pods newspace-web -n newspace -o wide
NAME                            READY   STATUS    RESTARTS   AGE     IP            
newspace-web   1/1     Running   0          2m22s   172.16.23.2   
~~~
So our `appspace-web` pod has an IP of `172.16.19.2` while our `newspace-web` pod has an IP of `172.16.23.2`. 

Let's deploy an apline linux pod in the `appspace` namespace and try to query the nginx webpage in the `newspace` namespace from the shell of the apline pod:
~~~
$ kubectl run test --namespace=appspace --rm -i -t --image=alpine -- sh

/ # wget -qO- --timeout=2 http://172.16.23.2

<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
~~~
(Feel free to try this same test the other way around (alpine pod in `newspace` quering pod in `appspace`, will work just the same)

Type `exit` to leave the alpine pod's shell and return to the cse-server's command prompt.

As mentioned in our previous Network Policy demo, the default config in Kubernetes is to allow all traffic to all pods in the cluster which is why we can communicate across namespaces in the example above. Now we can focus on locking each namespace down.

## Isolating Network Traffic per Namespace

The first thing we need to do is set a network policy on each namespace that will deny all ingress traffic to pods no matter the source, similar to a traditional firewall policies with a any-any-any-deny rule to drop all non-explicitly allowed traffic.

Let's navigate to the `~/zPod-PKS-CSE-Demos/NamespaceIsolation` directory on the cse-client server:
~~~
cd ~/zPod-PKS-CSE-Demos/NamespaceIsolation
~~~
Let's examine the `appspace-deny-all.yaml` file we'll use to create our deny all Network Policy for the `appspace` namespace:
~~~
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: appspace-deny-all
  namespace: appspace
spec:
  podSelector:
    matchLabels: {}
  policyTypes:
  - Ingress
~~~
This policy selects all pods in the namespace (because `spec.podSelector.matchLabels` is blank) as the source and leaves ingress undefined which means no inbound traffic allowed. This means that even pods within the `appspace` namespace can't communicate with each other

Let's also examine the `appspace-allow-pod.yaml` file, which will allow pod-to-pod traffic for all pods within the `appspace` namespace only:
~~~
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: appspace
  name: isolate-appspace
spec:
  podSelector:
    matchLabels:
  ingress:
  - from:
    - podSelector: {}
~~~
Again, because `spec.podSelector.matchLabels` is blank, this applies to all pods within the `appspace` namespace just like the deny all policy but in this example, we set a value for `spec.ingress.from.podSelector`, but leave it blank to allow ingress to ALL pods within the `appspace` namespace.

Now we are ready to deploy the 4 Network Policies in our cluster:
~~~
$ kubectl create -f appspace-deny-all.yaml
$ kubectl create -f appspace-isolate.yaml
$ kubectl create -f newspace-deny-all.yaml
$ kubectl create -f newspace-isolate.yaml
~~~
Confirm the Network Policies were created and applied to the correct namespaces:
~~~
$ kubectl get networkpolicy --all-namespaces
NAMESPACE   NAME                POD-SELECTOR   AGE
appspace    appspace-deny-all   <none>         13m
appspace    appspace-isolate    <none>         71s
newspace    newspace-deny-all   <none>         64s
newspace    newspace-isolate    <none>         55s
~~~
Now before we try our test again, let's hop over the NSX-T manager and have a look at the DFW rules that were created. log in to the [NSX-T manager](https://nsx.pks.zpod.io) and navigate to the **Advanced Network and Security** tab. Select the **Security** > **Distrubuted Firewall Rule** tab on the left hand menu. Locate the one of the `ip-pks-6e92c1a9-c8f2-4774-ba8b-7786e7fc8d50...` rules and expand the it:

![Screen Shot 2019-07-25 at 9 36 31 PM](https://user-images.githubusercontent.com/32826912/61919960-d4c76980-af25-11e9-95b6-ad2984d2a493.png)

The NSX Container Plugin (NCP) automatically created this rule to allow traffic from these two port groups when we created our network policy. If we click on both `Source` and `Destination` groups, we can gather more information about the members of the group:

![Screen Shot 2019-07-25 at 9 38 40 PM](https://user-images.githubusercontent.com/32826912/61919963-da24b400-af25-11e9-815c-a058eeb06827.png)

![Screen Shot 2019-07-25 at 9 39 04 PM](https://user-images.githubusercontent.com/32826912/61919966-dbee7780-af25-11e9-9909-0f2a991d65bf.png)

As we can see from the screenshots, the `source` and `destination` groups are both the same (the `172.16.23.0/24` network): the network assigned to our `newspace` namespace. This is the DFW rule that was created from our `newspace-isolate` Newtork Policy to allow pods within the `newspace` namespace to communicate with each other.

Let's look towards the bottom of the list and select one of the `pks-6e92c1a9-c8f2-4774-ba8b-7786e7fc8d50...` rules. Hover over the rule name until you find the one ending in `...newspace-deny-all` and examine this rule. This rule drops all traffic from source of `Any` to a target group. If we select the target group, we can can confirm this rule is applied to the `172.16.23.0/24` as well:

![Screen Shot 2019-07-25 at 9 45 50 PM](https://user-images.githubusercontent.com/32826912/61919970-ddb83b00-af25-11e9-8590-661ddb45f731.png)

This DFW rule was created by the NCP when we created our `newspace-deny-all` Network Policy.

Now we're finally ready to test our work! Let's deploy another apline linux pod in the `appspace` namespace and try to query the nginx webpage in the `newspace` namespace from the shell of the apline pod. We can also try to access the nginx webpage being served up by our app in the `appspace` namespace as well:
~~~
$ kubectl run test --namespace=appspace --rm -i -t --image=alpine -- sh

/ # wget -qO- --timeout=2 http://172.16.23.2
wget: download timed out

/ # wget -qO- --timeout=2 http://172.16.19.2
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
~~~
Our policies are working as expecting, pods can communicate with other pods in their own namespace but not pods in other namespaces.

## Examining Pod to Pod Traffic with Traceflow

The easiest way to troubleshoot connectivity between Pods or between Pods & VMs is to use NSX-T Traceflow. Traceflow could emulate any kind of traffic and it will show what is blocking it in case a Firewall Rule or a Kubernetes Network Policy is blocking that traffic. Let's emulate a traffic between our two nginx pods in seperate namespaces and see what happens.

Log in to the [NSX-T manager](https://nsx.pks.zpod.io) and the navigate to the **Advanced Network and Security** tab. Expand the **Tools** section in the left hand menu and select **Traceflow**. Now we need instruct Traceflow to emulate traffic between the logical ports that are connected to the virtual interfaces of the pods.

Under the **Source** section, select **Logical Port** from the dropdown menu. Then choose **VIF** as the attachment type as we are going to emulate traffic from the virtual interface of the pod. In the **Port** section, type `appspace-web` and select the logical port for our `appspace-web` pod:

![Screen Shot 2019-07-26 at 3 32 10 PM](https://user-images.githubusercontent.com/32826912/61977491-93ce6400-afbc-11e9-90cf-62705b2b44a4.png)

Repeat the proccess for **Destination** section but instead, reference the `appspace-web`'s virtual interface. Now select the **Trace** button:

![Screen Shot 2019-07-26 at 3 41 14 PM](https://user-images.githubusercontent.com/32826912/61977492-93ce6400-afbc-11e9-9230-41f4abbca2c8.png)

As we can see from the screenshot, the packet was dropped by our DFW rule, as expected. Now let's delete all of the network policies on the cluster and run the trace again by selecting the **Re-Trace** button in the top right hand corner:

~~~
$ cd ~/zPod-PKS-CSE-Demos/NamespaceIsolation
~~~
~~~
$ kubectl delete -f .
networkpolicy.networking.k8s.io "appspace-deny-all" deleted
networkpolicy.networking.k8s.io "appspace-isolate" deleted
networkpolicy.networking.k8s.io "newspace-deny-all" deleted
networkpolicy.networking.k8s.io "newspace-isolate" deleted
~~~

![Screen Shot 2019-07-26 at 3 45 03 PM](https://user-images.githubusercontent.com/32826912/61977493-93ce6400-afbc-11e9-952a-d538feb5e074.png)


Now that we've deleted the Network Policies, which in turn instructed the NCP to delete the DFW rules, our pods can communicate with each other again, as verified in the new trace above. Traceflow can be an incredibly helpful tool in helping our developers and infrastructure teams work together to troubleshoot network connectivity issues within Kubernetes clusters.

Now that we're done with our testing, let's head back over to the CLI of the cse-server and delete our nginx pods services:
~~~
$ kubectl delete pods -n newspace newspace-web
$ kubectl delete service -n newspace newspace-web
$ kubectl delete pods -n appspace appspace-web
$ kubectl delete service -n appspace appspace-web
~~~

## Conclusion

In this demo, we walked through the creation of Network Policies that allow Kubernetes cluster admins to isolate traffic within namespaces. With the help of the NCP, the creation of these Network Policies in turn produce DFW rules in NSX-T to restrict network traffic in our Kubernetes cluster. We also showcased the usage of the Traceflow tool to troubleshoot network connectivity between resources in our environment.

Head to the [next demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/UsingHarbor) to showcase utilizing Harbor as an enterprise grade cloud native registry in an Enterprise PKS deployment.
