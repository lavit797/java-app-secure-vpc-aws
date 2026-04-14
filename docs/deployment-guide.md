# Deployment Guide

## 1. Connect to Bastion Host
ssh -i aws-ec2.pem ubuntu@<bastion-ip>

## 2. Connect to Private EC2
ssh -i aws-ec2.pem ubuntu@<private-ip>

## 3. Install Java
sudo apt update -y
sudo apt install openjdk-17-jdk -y

## 4. Transfer JAR file
scp -i aws-ec2.pem app.jar ubuntu@<private-ip>:/home/ubuntu/

## 5. Run Application
java -jar app.jar --server.port=8000
