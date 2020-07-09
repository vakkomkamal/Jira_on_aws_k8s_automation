#!/usr/bin/env bash


#install kubectl

curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
kubectl version --short --client

echo "Installed kubectl"



#install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
echo "Installed eksctl"



#install aws-iam-authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mkdir -p $HOME/bin && cp ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
rm -rf aws-iam-authenticator
echo "installed aws-iam-authenticator"







#install aws cli
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
echo "Installed aws cli"
rm -rf aws
rm -rf awscliv2
rm -rf awscliv2.zip

echo "Please create a user with AdministratorAccess permission first and provide the below details"
aws configure

echo "Enter the name of the EKS cluster and ECR registry you want create: "
read clustername


aws ecr create-repository \
    --repository-name $clustername
echo "Enter the registryId from above: "
read registryID
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $registryID.dkr.ecr.us-west-2.amazonaws.com
sudo chmod 777 /var/run/docker.sock


docker build -t $registryID.dkr.ecr.us-west-2.amazonaws.com/$clustername:latest .
docker push $registryID.dkr.ecr.us-west-2.amazonaws.com/$clustername:latest

aws ecr create-repository \
    --repository-name postgres

cd postgres
docker build -t $registryID.dkr.ecr.us-west-2.amazonaws.com/postgres:latest .
docker push $registryID.dkr.ecr.us-west-2.amazonaws.com/postgres:latest
cd ..

eksctl create cluster \
--name $clustername \
--version 1.16 \
--region us-west-2 \
--nodegroup-name standard-workers \
--node-type t3.medium \
--nodes 1 \
--nodes-min 1 \
--ssh-access \
--ssh-public-key ~/.ssh/id_rsa.pub \
--managed

cat <<EOF> deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: jira
  labels:
    app: jira
spec:
  ports:
    - port: 8080
  selector:
    app: jira
    tier: frontend
  type: LoadBalancer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jira-pv-claim
  labels:
    app: jira
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
---
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: jira
  labels:
    app: jira
spec:
  selector:
    matchLabels:
      app: jira
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: jira
        tier: frontend
    spec:
      containers:
      - image: $registryID.dkr.ecr.us-west-2.amazonaws.com/atlassian:latest
        name: jira
        env:
        - name: JVM_MINIMUM_MEMORY
          value: 1024m
        - name: JVM_MAXIMUM_MEMORY
          value: 1024m
        - name: ATL_JDBC_URL
          value: jdbc:postgresql://jira-postgres:5432/jira_db
        - name: ATL_JDBC_USER
          value: jira_usr
        - name: ATL_JDBC_PASSWORD
          value: Password123
        - name: ATL_DB_DRIVER
          value: org.postgresql.Driver
        - name: ATL_DB_TYPE
          value: postgres72
        - name: ATL_DB_SCHEMA_NAME
          value: public
        ports:
        - containerPort: 8080
          name: jira
        volumeMounts:
        - name: jira-persistent-storage
          mountPath: /var/atlassian/application-data/jira
      volumes:
      - name: jira-persistent-storage
        persistentVolumeClaim:
          claimName: jira-pv-claim
EOF

cat <<EOF> postgres-deployment.yaml
apiVersion: v1
kind: Service
metadata:
  name: jira-postgres
  labels:
    app: jira
spec:
  ports:
    - port: 5432
  selector:
    app: jira
    tier: postgres
  clusterIP: None
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pv-claim
  labels:
    app: jira
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: jira-postgres
  labels:
    app: jira
spec:
  selector:
    matchLabels:
      app: jira
      tier: postgres
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: jira
        tier: postgres
    spec:
      containers:
      - image: $registryID.dkr.ecr.us-west-2.amazonaws.com/postgres:latest
        name: postgres
        env:
        - name: POSTGRES_USER
          value: jira_usr
        - name: POSTGRES_DB
          value: jira_db
        - name: POSTGRES_PASSWORD
          value: Password123
        ports:
        - containerPort: 5432
          name: postgres
        volumeMounts:
        - name: postgres-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: postgres-persistent-storage
        persistentVolumeClaim:
          claimName: postgres-pv-claim
EOF

kubectl apply -k ./
kubectl get svc -o wide
echo "access website using external address and port 8080 after 3 minutes, if you get error 503, wait for sometime and try again"
