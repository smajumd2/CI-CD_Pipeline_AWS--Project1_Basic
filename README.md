# CI-CD_Pipeline_AWS--Project1_Basic


AWS EKS CI/CD Pipeline with Jenkins, Docker, Tomcat & Terraform
An end-to-end DevOps CI/CD pipeline built on AWS. This project provisions infrastructure using Terraform, containerizes a Java/Tomcat web application using Docker, and automates deployment to an Amazon EKS (Kubernetes) cluster using a Jenkins pipeline.

Architecture Overview
Infrastructure Provisioning: Terraform sets up a dedicated AWS VPC, Subnets, Internet Gateway, Route Tables, IAM Roles, and an Amazon EKS Cluster with a Worker Node Group.

Containerization: Apache Tomcat (10.1-jdk17) packages and serves custom static web content (index.html).

Continuous Integration: Jenkins pulls source code, builds the Docker image, and pushes versioned tags to Docker Hub.

Continuous Deployment: Jenkins uses kubectl and AWS CLI to apply Kubernetes manifests to Amazon EKS, exposing the app via an AWS Load Balancer.

Prerequisites
AWS CLI configured (aws configure)

Terraform (v1.0+)

kubectl

Docker Desktop or Docker Engine

Jenkins running locally inside Docker

A Docker Hub account

A GitHub repository

Project Structure
Plaintext
aws-jenkins-k8s-project/
├── Dockerfile
├── index.html
├── Jenkinsfile
├── k8s-deployment.yaml
└── main.tf
Step 1: Infrastructure Provisioning (Terraform)
Create main.tf to provision the VPC, IAM roles, EKS Cluster, and Node Group on AWS.

Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 1. VPC & Networking
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "project-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-2" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. IAM Roles for EKS
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-group-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# 3. Amazon EKS Cluster & Node Group
resource "aws_eks_cluster" "eks" {
  name     = "app-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_node_group" "nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "app-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry,
  ]
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}
Commands to Run:
Bash
terraform init
terraform plan
terraform apply --auto-approve
Step 2: Web Application & Containerization
index.html
HTML
<!DOCTYPE html>
<html>
<head>
    <title>AWS EKS Tomcat App</title>
</head>
<body>
    <h1>Hello World! Deployed via Jenkins, Docker, Tomcat & Kubernetes on AWS!</h1>
</body>
</html>
Dockerfile
Dockerfile
FROM tomcat:10.1-jdk17

# Remove default webapps and place custom index page
RUN rm -rf /usr/local/tomcat/webapps/ROOT
COPY index.html /usr/local/tomcat/webapps/ROOT/index.html

EXPOSE 8080
CMD ["catalina.sh", "run"]
Step 3: Kubernetes Manifests
Create k8s-deployment.yaml to manage standard deployment replicas and LoadBalancer routing.

YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-app-deployment
  labels:
    app: tomcat-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tomcat-app
  template:
    metadata:
      labels:
        app: tomcat-app
    spec:
      containers:
      - name: tomcat-container
        image: sumitm84/tomcat-demo-app:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: tomcat-app-service
spec:
  type: LoadBalancer
  selector:
    app: tomcat-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
Step 4: Local Jenkins Container Setup
Run Jenkins in Docker with host Docker socket access:

Bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --user root \
  jenkins/jenkins:lts
Install Docker CLI, AWS CLI, and kubectl inside the running container:

Bash
docker exec -it -u root jenkins bash

# 1. Install Docker CLI
apt-get update && apt-get install -y docker.io curl unzip
chmod 666 /var/run/docker.sock

# 2. Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# 3. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

exit
Step 5: Jenkins Pipeline (Jenkinsfile)
Configure the automated build, push, and deployment steps in your Jenkinsfile:

Groovy
pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'sumitm84'
        APP_NAME        = 'tomcat-demo-app'
        IMAGE_TAG       = "${env.BUILD_NUMBER}"
        AWS_REGION      = 'us-east-1'
        EKS_CLUSTER     = 'app-eks-cluster'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${DOCKER_HUB_USER}/${APP_NAME}:${IMAGE_TAG} ."
                    sh "docker tag ${DOCKER_HUB_USER}/${APP_NAME}:${IMAGE_TAG} ${DOCKER_HUB_USER}/${APP_NAME}:latest"
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker-hub-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                        sh "docker login -u ${USER} -p ${PASS}"
                        sh "docker push ${DOCKER_HUB_USER}/${APP_NAME}:${IMAGE_TAG}"
                        sh "docker push ${DOCKER_HUB_USER}/${APP_NAME}:latest"
                    }
                }
            }
        }

        stage('Deploy to Amazon EKS') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh "aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}"
                        sh "aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}"
                        sh "aws configure set region ${AWS_REGION}"
                        sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}"
                        sh "kubectl apply -f k8s-deployment.yaml"
                    }
                }
            }
        }
    }
}
Step 6: Jenkins Credentials Setup
In Jenkins UI (Manage Jenkins > Credentials > System > Global credentials):

Docker Hub Credentials:

Kind: Username with password

ID: docker-hub-credentials

Username: Your Docker Hub username (sumitm84)

Password: Docker Hub password or Personal Access Token

AWS Credentials:

Kind: Username with password

ID: aws-credentials

Username: AWS_ACCESS_KEY_ID

Password: AWS_SECRET_ACCESS_KEY

GitHub Credentials (Required for private repositories):

Kind: Username with password

ID: github-credentials

Username: GitHub Username

Password: GitHub Personal Access Token (PAT)

Step 7: Verification & Testing
Trigger Build: Run Build Now on your Jenkins pipeline job.

Fetch Load Balancer URL:

Bash
kubectl get svc tomcat-app-service
Access Application:
Open the returned EXTERNAL-IP URL in your web browser:

Plaintext
http://<EXTERNAL-IP-LOADBALANCER-DNS>.elb.amazonaws.com
Check Pod & Deployment Health:
Bash
kubectl get pods -l app=tomcat-app
kubectl get deployment tomcat-app-deployment
kubectl logs -l app=tomcat-app --tail=50
Cleanup / Teardown
To stop incurring costs on AWS once finished, destroy all provisioned infrastructure using Terraform:

Bash
kubectl delete -f k8s-deployment.yaml
terraform destroy --auto-approve
