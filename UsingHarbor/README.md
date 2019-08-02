# Using Harbor as a Repository with Enterprise PKS

1. Pull docker image
~~~
$ docker pull nginxdemos/hello
~~~
2. Create public project in Harbor

3. Tag and Push docker image to Harbor repo
~~~
docker tag nginxdemos/hello harbor.pks.zpod.io/public-demo/hello:v1
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

5. Create private repo, add users, enable image scanning and enforcement

6. attempt to push image

7. Login if neccessary 

8. attempt to push image again

9. look at webUI, note vulnerabilities

10. create secret to allow image to be pulled

11. attempt to deploy application

