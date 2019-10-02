# CSE Tenant On-Boarding and RBAC Functionality Demo

![Picture1](https://user-images.githubusercontent.com/32826912/61664863-b3564b80-aca1-11e9-8cbd-9f796bb29382.png)

In this demo, we'll walk through the process of onboarding a tenant in vCD to deploy Enterprise PKS clusters via the Container Service Extension. We'll also utilize the RBAC funcitonality provided by CSE to ensure only certain users within the org can provision clusters. We are going to utilize the `enterprise-dev-org` tenant for this demo.

For future demos, there is a cluster (`demo-cluster`) provisioned with 3 worker nodes that you can use to deploy applications. This demo showcases the workflow for deploying a cluster via CSE. This cluster will only have 1 worker node to ensure the cluster provisions quickly. This cluster should not be used for the app demos as it may not have enough resources to support multiple applications.

**Note:** Ensure that you are using your Horizon instance (access instruction detailed [here](https://confluence.eng.vmware.com/display/CPCSA/CSE+zPod+Lab+Access+and+Demo+Scripts)) to access the demo environment.

## Step 1: Prepare Tenant Org

**1.1** Before starting the demo, access the `cse-client` server from your Horizon instance via putty (pw is `VMware1!`):

<img width="542" alt="Screen Shot 2019-08-02 at 8 30 20 PM" src="https://user-images.githubusercontent.com/32826912/62404702-6ce7d300-b564-11e9-8cce-145289c1e5e9.png">

**1.2** Once logged in to the `cse-client` server, run the clean-up script to ensure the `enterprise-dev-org` is not enabled to provision Enterprise PKS clusters:

(**Note**: please reach out to Joe Mann or ping in the `#zpod-feedback` slack channel for access credentials for the system admin user for this demo.)

~~~
$ ./zPod-PKS-CSE-Demos/CSERBACDemo/onboarding-demo-cleanup.sh
~~~

**1.3** Log in with the system admin user of the vCloud Director environment: 

~~~
$ vcd login director.vcd.zpod.io system administrator -iw
~~~

**1.4** Verify the `enterprise-dev-org` and it's corresponding OvDC is NOT enabled with a `k8 provider`

~~~
$ vcd cse ovdc list
name                org                 k8s_provider
------------------  ------------------  --------------
standard-demo-ovdc  cse-demo-org        native
ent-demo-ovdc       cse-demo-org        ent-pks
dev-ovdc            dev-org             native
ent-dev-ovdc        enterprise-dev-org  none
base-ovdc           base-org            none
prod-ovdc           prod-org            ent-pks
~~~

## Step 2: Enable the enterprise-dev-org for Enterprise PKS k8 Cluster Creation via CSE

**2.1** Add the right that allows an org to support Enterprise PKS cluster creation to our `enterprise-dev-org`:
~~~
$ vcd right add "{cse}:PKS DEPLOY RIGHT" -o enterprise-dev-org
~~~
**2.2** Ensure you are using the correct org and then enable the OvDC to support Enterprise PKS cluster creation with the following command:
~~~
$ vcd cse ovdc enable ent-dev-ovdc -o enterprise-dev-org -k ent-pks --pks-plan "dev-plan" --pks-cluster-domain "pks.zpod.io"
~~~
where `-k` is the k8 provider in question, `--pks-plan` is the PKS cluster [plan](https://docs.pivotal.io/pks/1-4/installing-pks-vsphere.html#plans) CSE will reference when a user provisions a cluster in this envrionment, and `--pks-cluster-domain` is the subdomain that we'll use for the hostname for kubernetes master API access whe a cluster is created.

Note: the `dev-plan` plan is just 1 master/1 worker, used for cluster creation demo as it only takes about 8 minutes to deploy.

**2.3** Verify the `enterprise-dev-org` tenant and the OvDC are enabled for Enterprise PKS cluster creation:
~~~
$ vcd cse ovdc list
name                org                 k8s_provider
------------------  ------------------  --------------
standard-demo-ovdc  cse-demo-org        native
ent-demo-ovdc       cse-demo-org        ent-pks
dev-ovdc            dev-org             native
ent-dev-ovdc        enterprise-dev-org  ent-pks
base-ovdc           base-org            none
prod-ovdc           prod-org            ent-pks
~~~

## Step 3: Add PKS Cluster Deploy Rights to Role

If we look at users in the `enterprise-dev-org` in vCloud Director, we can see that two users (dev1 and dev2) have the custom `k8deploy` role while another user (dev3), has the standard `vApp Author` role:

![Screen Shot 2019-07-22 at 5 17 21 PM](https://user-images.githubusercontent.com/32826912/61666075-9c652880-aca4-11e9-8177-e7bdc5ec0bdb.png)

We need to add the `"{cse}:PKS DEPLOY RIGHT"` right to the `k8deploy` role in order for our dev1 and 2 users to be able to deploy k8 clusters in this org.

**3.1** Instruct the `vcd-cli` to "use" the `enterprise-dev-org`:
~~~
$ vcd org use enterprise-dev-org
~~~
**3.2** Add the Enterprise PKS cluster deploy right to the custom role:
~~~
$ vcd role add-right "k8deploy" "{cse}:PKS DEPLOY RIGHT"
~~~
**3.3** Login to the `vcd-cli` with our `dev1` user to test a cluster creation:
~~~
$ vcd login director.vcd.zpod.io enterprise-dev-org dev1 -iwp VMware1!
~~~
~~~
$ vcd cse cluster create dev1-cluster
property                     value
---------------------------  ------------------------
kubernetes_master_host       dev1-cluster.pks.zpod.io
kubernetes_master_ips        In Progress
kubernetes_master_port       8443
kubernetes_worker_instances  1
last_action                  CREATE
last_action_description      Creating cluster
last_action_state            in progress
name                         dev1-cluster
worker_haproxy_ip_addresses
~~~

**3.4** If you'd like to access this cluster via `kubectl` on the cse server, you'll need to add the `kubernetes_master_ips` (will only be available after the cluster provision is complete) and `kubernetes_master_host` values into the `/etc/hosts` file of the cse server so the hostname will resolve correctly.

~~~
$ sudo vi /etc/hosts

#add the following line to the file
<kubernetes_master_ip>  dev1-cluster.pks.zpod.io
~~~
~~~
$ vcd cse cluster config dev1-cluster > ~/.kube/config
~~~
~~~
$ kubectl get nodes
NAME                                   STATUS   ROLES    AGE    VERSION
0faf789a-18db-4b3f-a91a-a9e0b213f310   Ready    <none>   10m    v1.13.5
~~~

**3.5** While you wait for the cluster to create (you can check status with `vcd cse cluster info dev1-cluster`), let's make sure RBAC is working as expected by logging into the org with our `dev3` user and trying to provision a cluster:
~~~
$ vcd login director.vcd.zpod.io enterprise-dev-org dev3 -iwp VMware1!
~~~
~~~
$ vcd cse cluster create rbac-test
Usage: vcd cse cluster create [OPTIONS] NAME
Try "vcd cse cluster create -h" for help.

Error: Access Forbidden. Missing required rights.
~~~
Perfect! So our `dev3` user does not have the `"{cse}:PKS DEPLOY RIGHT"` granted to their role so they aren't able to deploy clusters within the org.

## Step 4: CSE and NSX-T Integration

Whenever a PKS Kubernetes cluster is created via CSE, the CSE server reaches out directly to the NSX-T API upon cluster creation completion to create a Distributed Firewall rule to prevent any traffic from entering cluster from other clusters deployed in the environment.

**4.1** To verify this, after the `dev1-cluster` cluster creation is completed, log in to the [NSX-T manager](https://nsx.pks.zpod.io) and navigate to the **Advanced Network and Security** tab and then the **Security** > **Distrubuted Firewall Rule** tab on the left hand menu. Locate the `isolate-dev1-cluster...` DFW stanza and expand it to examine the 2 rules created:

![Screen Shot 2019-07-26 at 11 29 38 AM](https://user-images.githubusercontent.com/32826912/61963590-f8c49280-af99-11e9-8298-c2cd4eefead0.png)

**4.2** Examine the rules to understand what each one specifies. The first rule (Allow cluster node-pod to cluster node-pod communication), ensures that all pods within the `dev1-cluster` can communicate with each other. The second rule (Block cluster node-pod to all-node-pod communication) ensures that pods running in other clusters (`ALL_NODES_PODS`) can not reach the pods running in the `dev1-cluster`. We can examine the target groups these rules are applied to by selecting the hyperlink for each group within the rule:

![Screen Shot 2019-07-26 at 11 29 59 AM](https://user-images.githubusercontent.com/32826912/61963591-f8c49280-af99-11e9-8f0a-37f0565c1442.png)

![Screen Shot 2019-07-26 at 11 30 17 AM](https://user-images.githubusercontent.com/32826912/61963592-f8c49280-af99-11e9-9488-1231505662a1.png)

**4.3** Please delete the cluster after you finish this demo (you will use the `demo-cluster` for subsequest demo workflows):

~~~
$ vcd cse cluster delete dev1-cluster
~~~
CSE will delete the DFW rule create to isolate the cluster while the PKS control plane will handle deleting all additional NSX-T resources created to support the cluster.

**4.4** After deleting the cluster, please run the `onboarding-demo-cleanup.sh` script to clean to environment up for the next user:

~~~
$ ./zPod-PKS-CSE-Demos/CSERBACDemo/onboarding-demo-cleanup.sh
~~~

## Conclusion

In this demo, we walked through the onboarding of a new organization that wishes to deploy Enterprise PKS clusters via the Container Service Extention, granted users within the tenant org access to provision clusters, and demoed the creation of a cluster via CSE.

We also examined the work CSE does to isolate network traffic per cluster via NSX-T DFW rules any time a cluster is created via CSE. Move on to the [next demo](https://github.com/mann1mal/zPod-PKS-CSE-Demos/tree/master/GuestbookDemo) to start to deploy applications in Enterprise PKS Kubernetes clusters.




