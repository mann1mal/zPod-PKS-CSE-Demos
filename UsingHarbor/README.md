# Using Harbor with Enterprise PKS

In this demo, we will walk through the process of utilizing Harbor as an enterprise grade cloud native registry in conjunction with Enterprise PKS. Harbor can be [deployed as an OpsMan tile](https://docs.vmware.com/en/VMware-Enterprise-PKS/1.4/vmware-harbor-registry/GUID-installing.html) as part of an Enterprise PKS deployment (support for Harbor is included with Enterprise PKS). As Harbor is an open source project, it can also be deployed in a multitude of other environments/configurations. Please reference the [Harbor documentation](https://goharbor.io/docs/) for more details on deploying Harbor outside of an Enterprise PKS environment.

In the subsequent exercises, we will:

* create public and private projects
* upload container images to those projects 
* deploy applications to our `demo-cluster` using Harbor as our image registry
* explore security benefits provided by Harbor, such as automatic CVE scanning

Before starting the demo, access the `cse-client` CLI from your Horizon instance via putty (pw is `VMware1!`) if you haven't already:

<img width="542" alt="Screen Shot 2019-08-02 at 8 30 20 PM" src="https://user-images.githubusercontent.com/32826912/62404702-6ce7d300-b564-11e9-8cce-145289c1e5e9.png">

Also, let's ensure we are accessing the `demo-cluster` via kubectl by using `cse` to pull down the cluster config file and store it in the default location:
~~~
$ vcd login director.vcd.zpod.io cse-demo-org cse-ent-user -iwp VMware1!
~~~
~~~
$ vcd cse cluster config demo-cluster > ~/.kube/config
~~~
Now we're ready to start our Harbor lab.

## Using Public Projects
A project in Harbor is essentially a repository of container images and Helm charts that we can apply RBAC rules to in order to control what teams have access to what resources. For more information on manager projects, see the [Harbor documentaiton](https://github.com/goharbor/harbor/blob/master/docs/user_guide.md#managing-projects)

In this first exercise, we will create a public project, in which all users will have read access to the container images. We'll then upload a docker image to the project and deploy an app using that image in our `demo-cluster`.

First, we'll need to grab a docker image to use. We are going to grab the `nginx-hello` image from DockerHub. This image contains an NGINX webserver that serves a simple page containing its hostname, IP address and port as wells as the request URI and the local time of the webserver:
~~~
$ docker pull nginxdemos/hello
~~~
Verify the image has been pulled succesfully
~~~
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginxdemos/hello    latest              aedf47d433f1        18 months ago       16.8MB
~~~
Now, we'll need to log in to the Harbor web UI to create our projects. Navigate to `harbor.pks.zpod.io` and login with `admin/VMware1!`. Once logged in, click the `New Project` button to create a project. Fill in the project name (`public-demo`) and ensure the `Public` option is selected:

![Screen Shot 2019-08-02 at 3 07 05 PM](https://user-images.githubusercontent.com/32826912/62405040-be459180-b567-11e9-9109-ac79d6b94588.png)

After creating the project, we need to tag our docker image and push it to Harbor. Run the following command to tag the `hello` image:
~~~
$ docker tag nginxdemos/hello harbor.pks.zpod.io/public-demo/hello:v1
~~~
Verify the tag was applied correctly:
~~~
$ docker images
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
nginxdemos/hello                       latest              aedf47d433f1        18 months ago       16.8MB
harbor.pks.zpod.io/public-demo/hello   v1                  aedf47d433f1        18 months ago       16.8MB
~~~
Push the image to our `public-demo` project
~~~
docker push harbor.pks.zpod.io/public-demo/hello:v1
~~~
Navigate back to the web UI and click on the `public-demo` link and verify the image has been uploaded and is visible in the `Repositories` tab:

![Screen Shot 2019-08-02 at 3 09 38 PM](https://user-images.githubusercontent.com/32826912/62405085-4330ab00-b568-11e9-8f06-8bb49785cf9e.png)

Now that the image has been uploaded to our project, let's deploy an application in our Kubernetes cluster using the image.

Navigate to the `~/zPod-PKS-CSE-Demos/UsingHarbor` directory:
~~~
$ cd ~/zPod-PKS-CSE-Demos/UsingHarbor
~~~
Examine the `nginx-hello.yaml` file, which contains configuration files for our deployment, including an ingress resource to allow us to access the application from outside the cluster. Note the image name reference in the pod spec:
~~~
---output omitted---
    spec:
      containers:
      - image: harbor.pks.zpod.io/public-demo/hello:v1
        name: hello
---output omitted---
~~~
Run the following command to create a deployment of the app in our Kubernetes cluster:
~~~
$ kubectl create -f nginx-hello.yaml
~~~
Monitor the deployment and wait for the pod to become ready:
~~~
$ k get pods -w
NAME                         READY   STATUS    RESTARTS   AGE
hello-app-6d78887559-27mjp   1/1     Running   0          9s
~~~
Let's examine the deployment to ensure we are using the image we uploaded to our Harbor project:
~~~
$ kubectl describe deploy hello-app
---output ommitted---
Pod Template:
  Labels:  app=hello
  Containers:
   hello:
    Image:        harbor.pks.zpod.io/public-demo/hello:v1 <-- uploaded image
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
---output omitted---
~~~
Let's query our ingress resource to access the hostname for our application and access the application via a brower:
~~~
$ kubectl get ingress
NAME            HOSTS                    ADDRESS                     PORTS   AGE
hello-ingress   hello.demo.pks.zpod.io   10.96.59.106,100.64.32.27   80      56s
~~~

![Screen Shot 2019-08-02 at 3 45 17 PM](https://user-images.githubusercontent.com/32826912/62405315-ef26c600-b569-11e9-89fc-a2e71649a713.png)

Great!! We were able to succesfully upload our image to the Harbor project and deploy an app using that image to our Kubernetes cluster. Now let's clean up our cluster for the next demo:
~~~
$ kubectl delete -f nginx-hello.yaml
~~~

## Using Private Projects

In this exercise, we are going to create a private project, which can only be accessed by users who are specifically granted access. This allows admins to control which teams have access to which set of resources being offered by Harbor. This private project will only be accessed by our `dev1` development team.

First, we'll need to navigate back to the home page of Harbor web UI, click the `New Project` button, define our project name (`private-demo`), and ensure the `Public` check box is NOT selected:

<img width="1440" alt="Screen Shot 2019-08-02 at 9 15 55 PM" src="https://user-images.githubusercontent.com/32826912/62405391-c3f0a680-b56a-11e9-9d74-019e5392caef.png">

After creating the project, we need to add our `dev1` user to Harbor's local user directory and add that user to our private project to grant them access. 

Select the `Users` tab in the `Administration` section on the left-hand menu. Select the `New-User` button and fill in the requested credentials as detailed in the screenshot below:

![Screen Shot 2019-08-02 at 3 57 00 PM](https://user-images.githubusercontent.com/32826912/62405464-6446cb00-b56b-11e9-9d32-c91e8200fa09.png)

After adding the user, select the `Projects` tab in the left-hand menu. Select the link for the `private-project` and select the `Members` tab. Select the `+ User` button and add the `dev1` user as `Project Admin`, which will allow them to manage the private project:

**Note**: You must select the username from the drop down. Begin typing `private-demo..` and select the username from the dropdown menu

![Screen Shot 2019-08-02 at 3 53 19 PM](https://user-images.githubusercontent.com/32826912/62405466-6872e880-b56b-11e9-84b5-67152b4154c7.png)

Now that we've added our user to our private project, let's enable soome additional security feature for this project. Navigate to the `Configuration` tab and ensure both the `Automatically scan images on push` and `Prevent vulnerable images from running` options are enabled. Set the threshold for image vulnerability to `Medium`:

![Screen Shot 2019-08-02 at 3 50 42 PM](https://user-images.githubusercontent.com/32826912/62405535-986ebb80-b56c-11e9-8242-f5cb750175a9.png)

This will ensure that any time an image is pushed to the project, it is automatically scanned for CVE vulnerabilities. Harbor utilizes [Clair](https://coreos.com/clair/docs/latest/) to scan images for vulnerabilites. We also set a process in place to prevent an image from being pulled if it has medium or higher level severities reported.

Let's head back over to the `cse-client` putty session and push our image to our private project.

Tag the image to prepare it to be pushed to the private project:
~~~
$ docker tag nginxdemos/hello harbor.pks.zpod.io/private-demo/hello:v1
~~~
Attempt to push the image to the project project:
~~~
$ docker push harbor.pks.zpod.io/private-demo/hello:v1
The push refers to repository [harbor.pks.zpod.io/private-demo/hello]
fc9922555bc3: Preparing 
767e894eb5e9: Preparing 
e45dbf549a90: Preparing 
f93c2b24cb18: Preparing 
343bb8320f2b: Preparing 
7066df57739c: Waiting 
d39d92664027: Waiting 
denied: requested access to the resource is denied   <<--- Access Denied
~~~
Note that we are not able to push the image as we get an `Access Denied` message. This is expected behavior as our private project requires authentication. Authenticate to the Harbor instance with the `dockr login` command:
~~~
$ docker login harbor.pks.zpod.io
Username: private-demo-dev1
Password: 

Login Succeeded
~~~
Now let's try to push the image again:
~~~
$ docker push harbor.pks.zpod.io/private-demo/hello:v1
The push refers to repository [harbor.pks.zpod.io/private-demo/hello]
fc9922555bc3: Layer already exists 
767e894eb5e9: Layer already exists 
e45dbf549a90: Layer already exists 
f93c2b24cb18: Layer already exists 
343bb8320f2b: Layer already exists 
7066df57739c: Layer already exists 
d39d92664027: Layer already exists 
v1: digest: sha256:f5a0b2a5fe9af497c4a7c186ef6412bb91ff19d39d6ac24a4997eaed2b0bb334 size: 1775
~~~
This time it succeeded!! Let's have a look at the Harbor web UI and verify our image was pushed to the project. Navigate to the Harbor homepage and select the `private-demo` link.

9. look at webUI, note vulnerabilities

<screenshot>

10. Attempt to deploy workload:
~~~
$ kubectl create -f private-nginx-hello.yaml
~~~
~~~
$ kubectl get pods
NAME                                 READY   STATUS             RESTARTS   AGE
private-hello-app-7844dc7479-bl7jn   0/1     ImagePullBackOff   0          22s
~~~
~~~
$ kubectl describe po private-hello-app-7844dc7479-bl7jn
---output omitted---
rpc error: code = Unknown desc = Error response from daemon: unknown: The severity of vulnerability of the image: "high" is equal or higher than the threshold in project setting: "medium".
---output omitted---
~~~
11. Go back to web UI and disable policy, try again.
~~~
$ kubectl delete -f private-nginx-hello.yaml 
~~~
~~~
$ kubectl create -f private-nginx-hello.yaml 
~~~
~~~
$ kubectl get po
NAME                                 READY   STATUS         RESTARTS   AGE
private-hello-app-7844dc7479-ljrrc   0/1     ErrImagePull   0          34s
~~~
~~~
$ kubectl describe po private-hello-app-7844dc7479-ljrrc
---output omitted---
Failed to pull image "harbor.pks.zpod.io/private-demo/hello:v1": rpc error: code = Unknown desc = Error response from daemon: pull access denied for harbor.pks.zpod.io/private-demo/hello, repository does not exist or may require 'docker login'
---output omitted---
~~~
10. create secret to allow image to be pulled
~~~
$ kubectl create secret generic private-demo-secret \
> --from-file=.dockerconfigjson=/home/joe/.docker/config.json \
> --type=kubernetes.io/dockerconfigjson
~~~
11. Add secret to pod spec:
~~~
---output omitted---
    spec:
      containers:
      - image: harbor.pks.zpod.io/private-demo/hello:v1
        name: private-hello
        ports:
        - containerPort: 80
      imagePullSecrets:
      - name: private-demo-secret
---output omitted---
12. Deploy app again
~~~
$ kubectl create -f private-nginx-hello.yaml 
~~~
~~~
$ kubectl get pods -w
private-hello-app-77564f9459-w2hz8   1/1     Running   0          8s
~~~
~~~
$ kubectl get ingress
NAME            HOSTS                            ADDRESS                     PORTS   AGE
hello-ingress   private-hello.demo.pks.zpod.io   10.96.59.106,100.64.32.27   80      56s
~~~
<screenshot>
