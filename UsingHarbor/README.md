# Using Harbor as a Repository with Enterprise PKS

## Using Public Projects

1. Pull docker image
~~~
$ docker pull nginxdemos/hello
~~~
~~~
$ docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginxdemos/hello    latest              aedf47d433f1        18 months ago       16.8MB
~~~
2. Create public project in Harbor

<screenshots>

3. Tag and Push docker image to Harbor repo
~~~
$ docker tag nginxdemos/hello harbor.pks.zpod.io/public-demo/hello:v1
~~~
~~~
$ docker images
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
nginxdemos/hello                       latest              aedf47d433f1        18 months ago       16.8MB
harbor.pks.zpod.io/public-demo/hello   v1                  aedf47d433f1        18 months ago       16.8MB
~~~
~~~
docker push harbor.pks.zpod.io/public-demo/hello:v1
~~~

<screenshot of UI>

4. Deploy k8 deployment with image from Harbor (with ingress)
~~~
$ kubectl create -f nginx-hello.yaml
~~~
~~~
$ kubectl describe deploy hello-app
---output ommitted---
Pod Template:
  Labels:  app=hello
  Containers:
   hello:
    Image:        harbor.pks.zpod.io/public-demo/hello:v1
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
---output omitted---
~~~
~~~
$ kubectl get ingress
NAME            HOSTS                    ADDRESS                     PORTS   AGE
hello-ingress   hello.demo.pks.zpod.io   10.96.59.106,100.64.32.27   80      56s
~~~

5. Access URL of app

< screenshot >

6. Clean up
~~~
$ kubectl delete -f nginx-hello.yaml
~~~

## Using Private Projects

1. Create new project, create user, add user to project as project admin

2. Tag image to push to new repo:

~~~
$ docker tag nginxdemos/hello harbor.pks.zpod.io/private-demo/hello:v1
~~~
3. Attempt to push image:
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

7. Login if neccessary 
~~~
$ docker login harbor.pks.zpod.io
Username: private-demo-dev1
Password: 

Login Succeeded
~~~

8. attempt to push image again

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
