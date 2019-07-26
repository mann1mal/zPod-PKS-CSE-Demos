# Namespace Network Isolation with Network Policies and NSX-T

As was pointed out in our [first demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/CSERBACDemo), the Container Service Exstension automatically provisions NSX-T Distributed Firewall rules to ensure that each clusters' workloads are isolated from other clusters' workloads. But what if you'd like to share a single cluster with multiple users/groups instead of provision a dedicated cluster for each group?

One option is to utilize Network Policies to ensure network traffic can not traverse [namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) within a cluster. In one of our previous demos, we created the `appspace` namespace to house our applications. We're now going to onboard a new team that will deploy their applications to the `newspace` namespace. We'll also ensure pods from each namespace can't communicate with each other.

As detailed in the [previous demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/NetworkPolicy) Enterprise PKS Kubernetes clusters using NSX-T as the Container Network Interface (CNI) will have DFW rules automatically created in NSX-T when we create Network Policies. We will showcase this functionality again in this demo to isolate namespace network traffic.

## Testing Default Kubernetes Pod-to-Pod Network Connectivity
Before you start the demo, let's ensure we are accessing the `demo-cluster`:
~~~
$ vcd login director.vcd.zpod.io cse-demo-org cse-ent-user -iwp VMware1!
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
