
mvn clean package
target/app.jar
scp -i aws-ec2.pem target/app.jar ubuntu@<bastion-public-ip>:/home/ubuntu/
scp -i aws-ec2.pem app.jar ubuntu@<private-ec2-ip>:/home/ubuntu/
ssh -i aws-ec2.pem ubuntu@<private-ec2-ip>
sudo apt update -y
sudo apt install openjdk-17-jdk -y
java -version
java -jar target/app.jar --server.port=8000

