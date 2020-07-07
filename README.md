# Jira_on_aws_k8s_automation

Deploy Jira in aws EKS kubernetes in a automated fashion. Postgresql is also integrated as environment variable and you don't need to configure it. Will customize docker image for adding db driver.
This will deploy everything automatically through aws api, will create a 'Cloud Formation' cluster, you will be able to do kubectl from the system you are installing. This will also create two ECR registry, 
one for Jira and one for database.




1. You can do this with a aws free tier account, login and go to IAM and create a user with "AdministerAccess" privilege and obtain 
   AWS Access Key ID
   AWS Secret Access Key
   Everything else is automated, even databe connection.
2. You have to run this from a linux system, tested in ubuntu. If you don't have linux, just install a virtual box and install ubuntu in it,
   also docker engine need to be installed.
3. Run "solution_start.sh" with command "bash solution_start.sh"
4. This will prompt for a name for your EKS kubernetes cluster, everything else will be done automatically
5. This will automatically create ECR docker registry, you need to copy paste registryID upon creation. 
   Will prompt for registryID< just need to copy from above line, no need to go to console.
6. The script will build docker image and push to ECR docker registry in a automated way.
7. Will deploy customized docker image Jira and Postgresql in the aws kuberenetes cluster.
8. Please make changes in Dockerfile inside postgres folder and also in jira_deployment.yaml if you want to change default database values.

