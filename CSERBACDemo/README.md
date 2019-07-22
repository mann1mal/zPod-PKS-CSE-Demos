# CSE RBAC Functionality Demo

![Picture1](https://user-images.githubusercontent.com/32826912/61664863-b3564b80-aca1-11e9-8cbd-9f796bb29382.png)

In this demo, we'll walk through the process of onboarding a tenant in vCD to deploy Enterprise PKS clusters via the Container Service Extension. We'll also utilize the RBAC funcitonality provided by CSE to ensure only certain users within the org can provision clusters. We are going to utilize the `enterprise-dev-org` tenant for this demo.

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
vcd right add "{cse}:PKS DEPLOY RIGHT" -o enterprise-dev-org
~~~
Now, we need to ensure we are using the correct org and then enable the OvDC to support Enterprise PKS cluster creation with the following command:
~~~
vcd cse ovdc enable ent-dev-ovdc -o enterprise-dev-org -k ent-pks --pks-plan "x-small" --pks-cluster-domain "pks.zpod.io"
~~~
where `-k` is the k8 provider in question, `--pks-plan` is the PKS cluster [plan](https://docs.pivotal.io/pks/1-4/installing-pks-vsphere.html#plans) CSE will reference when a user provisions a cluster in this envrionment, and `--pks-cluster-doman` is the subdomain that we'll use for the hostname for kubernetes master API access.
