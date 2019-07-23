# CSE Tenant On-Boarding and RBAC Functionality Demo

![Picture1](https://user-images.githubusercontent.com/32826912/61664863-b3564b80-aca1-11e9-8cbd-9f796bb29382.png)

In this demo, we'll walk through the process of onboarding a tenant in vCD to deploy Enterprise PKS clusters via the Container Service Extension. We'll also utilize the RBAC funcitonality provided by CSE to ensure only certain users within the org can provision clusters. We are going to utilize the `enterprise-dev-org` tenant for this demo.

**Note:** Ensure that you are using your Horizon instance (access instruction detailed [here](https://confluence.eng.vmware.com/display/CPCSA/CSE+zPod+Lab+Access+and+Demo+Scripts)) to access the demo environment.

## Prepare Tenant Org

First, ensure that you are logged in to your Horizon instance and ssh to the cse-client server:
~~~
$ ssh cse@cse-client.vcd.zpod.io
VMware1!
~~~
Once on the cse-client, run the clean-up script to ensure the `enterprise-dev-org` is not enabled to provision Enterprise PKS clusters:
~~~
$ ./demofiles/onboarding-demo-cleanup.sh
~~~
Verify the `enterprise-dev-org` and it's corresponding OvDC is NOT enabled with a `k8 provider`
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

## Enable the enterprise-dev-org for Enterprise PKS k8 Cluster Creation via CSE

First, we need to add the right that allows an org to support Enterprise PKS clusters to our `enterprise-dev-org`:
~~~
$ vcd right add "{cse}:PKS DEPLOY RIGHT" -o enterprise-dev-org
~~~
Now, we need to ensure we are using the correct org and then enable the OvDC to support Enterprise PKS cluster creation with the following command:
~~~
$ vcd cse ovdc enable ent-dev-ovdc -o enterprise-dev-org -k ent-pks --pks-plan "x-small" --pks-cluster-domain "pks.zpod.io"
~~~
where `-k` is the k8 provider in question, `--pks-plan` is the PKS cluster [plan](https://docs.pivotal.io/pks/1-4/installing-pks-vsphere.html#plans) CSE will reference when a user provisions a cluster in this envrionment, and `--pks-cluster-doman` is the subdomain that we'll use for the hostname for kubernetes master API access whe a cluster is created.

Note: the `x-small` plan is just 1 master/1 worker, so nice and small for cluster creation demo.

Now let's verify the `enterprise-dev-org` tenant and the OvDC are enabled for Enterprise PKS cluster creation:
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
If we look at users in the `enterprise-dev-org` in vCloud Director, we can see that two users (dev1 and dev2) have the custom `k8deploy` role while another user (dev3):

![Screen Shot 2019-07-22 at 5 17 21 PM](https://user-images.githubusercontent.com/32826912/61666075-9c652880-aca4-11e9-8177-e7bdc5ec0bdb.png)

We need to add the `"{cse}:PKS DEPLOY RIGHT"` right to the `k8deploy` role in order for our dev1 and 2 users to be able to deploy k8 clusters in this org:
~~~
$ vcd role add-right "k8deploy" "{cse}:PKS DEPLOY RIGHT"
~~~
Now let's login to the vcd-cli with our dev1 user to test a cluster creation:
~~~
$ vcd login director.vcd.zpod.io enterprise-dev-org dev1 -iwp VMware1!

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

While you wait for the cluster to create (you can check status with `vcd cse cluster info dev1-cluster`), let's make sure RBAC is working as expected by logging into the org with our dev3 user and trying to provision a cluster:
~~~
$ vcd login director.vcd.zpod.io enterprise-dev-org dev3 -iwp VMware1!

$ vcd cse cluster create rbac-test
Usage: vcd cse cluster create [OPTIONS] NAME
Try "vcd cse cluster create -h" for help.

Error: Access Forbidden. Missing required rights.
~~~
Perfect! So our dev3 user does not have the `"{cse}:PKS DEPLOY RIGHT"` granted to their role so they aren't able to deploy clusters within the org.
