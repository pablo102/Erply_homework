Erply homework
This Terraform AWS code will deploy random PHP application from github that will run on Nginx webserver.

Terraform script will create:
1) VPC in eu-west-1 region.
2) 2 subnets for high-availability.
3) Security group with 22, 80 ports.
4) EC2 instance with application installation.
5) Auto-scalling depend on CPU.
6) Log streaming to CloudWatch.

Instructions to deploy:
1) Create new IAM user with access keys and generate new Key Pair.
2) Connect AWS credentials in work machine.
3) Install Terraform.
4) Clone https://github.com/pablo102/Erply_homework.git and provide your Key Pair.
5) Inside cloned folder make command: terraform init && terraform apply
