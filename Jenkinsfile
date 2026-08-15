pipeline {
    agent any

    environment {
        DOCKER_HUB_USER = 'sumitm84' // Replace with your Docker Hub username
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