## Installing Kubeapps


Install helm

**Security Disclaimer**
~~~
cd ~/zPod-PKS-CSE-Demos/Kubeapps
~~~

~~~
kubectl create -f helm-rbac-config.yaml
~~~

~~~
helm init --service-account tiller
~~~

~~~
k get po -n kube-system
NAME                                    READY   STATUS    RESTARTS   AGE
coredns-95489c5c9-btdq7                 1/1     Running   0          4h55m
coredns-95489c5c9-p95nf                 1/1     Running   0          4h55m
coredns-95489c5c9-wv2vz                 1/1     Running   0          4h55m
kubernetes-dashboard-558689fc66-bd9kk   1/1     Running   0          4h55m
metrics-server-867b8fdb7d-mflv6         1/1     Running   0          4h55m
tiller-deploy-9bf6fb76d-gbcks           1/1     Running   0          40s
~~~

~~~
helm repo add bitnami https://charts.bitnami.com/bitnami
~~~

~~~
kubectl create namespace kubeapps
~~~

~~~
kubectl create clusterrolebinding kubeapps-operator \
--clusterrole=cluster-admin \
--serviceaccount=default:kubeapps-operator
~~~

~~~
helm install --name kubeapps --namespace kubeapps bitnami/kubeapps \
--set mongodb.securityContext.enabled=false \
--set mongodb.mongodbEnableIPv6=false
~~~

~~~
$ kubectl get pods,services -n kubeapps
NAME                                                             READY   STATUS      RESTARTS   AGE
pod/apprepo-sync-bitnami-bnf7j-d8vp5                             1/1     Running     1          53s
pod/apprepo-sync-incubator-z2zq6-jkv96                           0/1     Completed   1          53s
pod/apprepo-sync-stable-9pw4s-gtbhf                              1/1     Running     1          53s
pod/apprepo-sync-svc-cat-sb25z-6npsd                             0/1     Completed   1          53s
pod/kubeapps-6c8d4bf9c-8m7b6                                     1/1     Running     0          64s
pod/kubeapps-6c8d4bf9c-lb85h                                     1/1     Running     0          64s
pod/kubeapps-internal-apprepository-controller-55fcd5966-ht8vc   1/1     Running     0          64s
pod/kubeapps-internal-chartsvc-7fc7bc4fc5-jp48r                  1/1     Running     1          64s
pod/kubeapps-internal-chartsvc-7fc7bc4fc5-v987s                  1/1     Running     1          64s
pod/kubeapps-internal-dashboard-676d44f9f5-hffxw                 1/1     Running     0          64s
pod/kubeapps-internal-dashboard-676d44f9f5-nwknr                 1/1     Running     0          64s
pod/kubeapps-internal-tiller-proxy-696ffcd799-jjc7w              1/1     Running     0          64s
pod/kubeapps-internal-tiller-proxy-696ffcd799-lhfkw              1/1     Running     0          64s
pod/kubeapps-mongodb-6cbcc9ffd4-lgnb5                            1/1     Running     0          64s

NAME                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)     AGE
service/kubeapps                         ClusterIP   10.100.200.227   <none>        80/TCP      64s
service/kubeapps-internal-chartsvc       ClusterIP   10.100.200.13    <none>        8080/TCP    64s
service/kubeapps-internal-dashboard      ClusterIP   10.100.200.28    <none>        8080/TCP    64s
service/kubeapps-internal-tiller-proxy   ClusterIP   10.100.200.69    <none>        8080/TCP    64s
service/kubeapps-mongodb                 ClusterIP   10.100.200.138   <none>        27017/TCP   64s
~~~

~~~
kubectl create -f kubeapps-ingress.yaml
~~~

~~~
kubectl get ingress -n kubeapps
~~~

~~~
kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{.secrets[].name}') \
-o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo
~~~

~~~
kubectl create namespace wordpress
~~~

run through UI to create wordpress app, change persistance

~~~
kubectl get pods -n wordpress -w
NAME                                  READY   STATUS    RESTARTS   AGE
cut-birds-mariadb-0                   0/1     Running   0          19s
cut-birds-wordpress-fbb7f5b76-lm5bh   0/1     Running   0          19s
cut-birds-mariadb-0   1/1   Running   0     38s
cut-birds-wordpress-fbb7f5b76-lm5bh   1/1   Running   0     112s
~~~

~~~
$ kubectl get all -n wordpress
NAME                                      READY   STATUS    RESTARTS   AGE
pod/cut-birds-mariadb-0                   1/1     Running   0          2m33s
pod/cut-birds-wordpress-fbb7f5b76-lm5bh   1/1     Running   0          2m33s

NAME                          TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                      AGE
service/cut-birds-mariadb     ClusterIP      10.100.200.87   <none>         3306/TCP                     2m33s
service/cut-birds-wordpress   LoadBalancer   10.100.200.72   10.96.59.115   80:32370/TCP,443:31918/TCP   2m33s

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cut-birds-wordpress   1/1     1            1           2m33s

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/cut-birds-wordpress-fbb7f5b76   1         1         1       2m33s

NAME                                 READY   AGE
statefulset.apps/cut-birds-mariadb   1/1     2m33s
~~~

~~~
$ helm ls
NAME     	REVISION	UPDATED                 	STATUS  	CHART          	APP VERSION	NAMESPACE
cut-birds	1       	Tue Oct  1 16:58:19 2019	DEPLOYED	wordpress-7.3.8	5.2.3      	wordpress
kubeapps 	1       	Tue Oct  1 16:22:52 2019	DEPLOYED	kubeapps-2.1.5 	v1.5.1     	kubeapps 
~~~

~~~
$ echo Password: $(kubectl get secret --namespace wordpress cut-birds-wordpress -o jsonpath="{.data.wordpress-password}" | base64 --decode)
Password: <your-password>
~~~

