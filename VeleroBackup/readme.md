## Backing up your Kubernetes Application with Velero
~~~
cd ~/zPod-PKS-CSE-Demos/VeleroBackup
~~~
~~~
$ kubectl create namespace velero
~~~
~~~
$ kubectl create -f minio-storage-class.yaml 
~~~
~~~
$ kubectl create -f velero-pvc.yaml
~~~
~~~
$ kubectl create -f minio-deploy.yaml 

deployment.apps/minio created
service/minio created
secret/cloud-credentials created
job.batch/minio-setup created
ingress.extensions/velero-minio created
~~~
~~~
$ kubectl expose deployment minio --name=velero-minio-lb --port=9000 --target-port=9000 --type=LoadBalancer --namespace=velero
~~~
~~~
$ kubectl get services -n velero
~~~
**For whatever reason, can not hit the Minio service on the LB, logo spins... back to old problem with L4 LB...Maybe deploy ingress eventually?**
~~~
$ cat credentials-velero
~~~
~~~
$ velero install  --provider aws --bucket velero --secret-file credentials-velero \
--use-volume-snapshots=false --use-restic --backup-location-config \ region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000,publicUrl=http://<public-ip-minio-service>:9000

---output omitted---

Velero is installed! ⛵ Use 'kubectl logs deployment/velero -n velero' to view the status.
~~~
~~~
$ kubectl get pod -n velero
NAME                      READY   STATUS             RESTARTS   AGE
minio-5559c4749-7xssq     1/1     Running            0          7m21s
minio-setup-dhnrr         0/1     Completed          0          7m21s
restic-mwgsd              0/1     CrashLoopBackOff   4          2m17s
restic-xmbzz              0/1     CrashLoopBackOff   4          2m17s
restic-235cz              0/1     CrashLoopBackOff   4          2m17s
velero-7d876dbdc7-z4tjm   1/1     Running            0          2m17s
~~~
As mentioned above, the restic pods are not able to start. That is because in Enterprise PKS Kubernetes clusters, the path to the pods on the nodes is a little different (/var/vcap/data/kubelet/pods) than in "vanilla" Kubernetes clusters (/var/lib/kubelet/pods). In order for us to allow the restic pods to run as expected, we need to edit the restic daemon set and change the hostPath variable as referenced below:
~~~
$ kubectl edit daemonset restic -n velero
~~~
~~~
volumes:
      - hostPath:
          path: /var/vcap/data/kubelet/pods
          type: ""
        name: host-pods
~~~
~~~
$ kubectl get pod -n velero

NAME                      READY   STATUS      RESTARTS   AGE
minio-5559c4749-7xssq     1/1     Running     0          12m
minio-setup-dhnrr         0/1     Completed   0          12m
restic-p4d2c              1/1     Running     0          6s
restic-xvxkh              1/1     Running     0          6s
restic-e31da              1/1     Running     0          6s
velero-7d876dbdc7-z4tjm   1/1     Running     0          7m36s
~~~

~~~
$kubectl get pods -n wordpress

NAME                                  READY   STATUS    RESTARTS   AGE
cut-birds-mariadb-0                   1/1     Running   0          23h
cut-birds-wordpress-fbb7f5b76-lm5bh   1/1     Running   0          23h
~~~
~~~
$ kubectl -n wordpress annotate pod/<maria-db-pod-name> backup.velero.io/backup-volumes=data,config
$ kubectl -n wordpress annotate pod/<wordpress-pod-name> backup.velero.io/backup-volumes=wordpress-data
~~~
~~~
$ velero backup create wordpress-backup --include-namespaces wordpress
~~~
~~~
$ velero backup describe wordpress-backup
~~~
~~~
$ kubectl get pods -n wordpress
$ kubectl get pvc -n wordpress
~~~
~~~
$ kubectl delete namespace wordpress
~~~
~~~
$ kubectl get pods -n wordpress
$ kubectl get pvc -n wordpress
~~~
~~~
$ velero backup get
~~~
~~~
$ velero restore create --from-backup wordpress-backup
~~~
~~~
$kubectl get po -n wordpress -w
~~~
Access the IP of the wordpress application

Boom!!!




