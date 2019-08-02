# Using Harbor as a Repository with Enterprise PKS

1. Build docker image

2. Create public project in Harbor

3. Push docker image to Harbor repo

4. Deploy k8 deployment with image from Harbor (with ingress)

5. Create private repo, add users, enable image scanning and enforcement

6. attempt to push image

7. Login if neccessary 

8. attempt to push image again

9. look at webUI, note vulnerabilities

10. create secret to allow image to be pulled

11. attempt to deploy application

