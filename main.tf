#Create a key pair for ec2 and update it to write access
#Remember to update aws configure for the below key pair to work
#aws ec2 create-key-pair --key-name my-ec2-key --query 'KeyMaterial' --output text > ./my-ec2-key.pem
#Linux
#chmod 600 /root/my-ec2-key.pem
#Windows
#icacls "C:\Users\jjusi\terraform-project\AWS-project\my-ec2-key.pem" /inheritance:r /grant:r "jjusi:F"

#Creating your ec2 resource hosted on WebServer1 & 2
#ami number is an input to update
resource "aws_instance" "WebServer1" {
  ami             = "ami-06c68f701d8090592"
  instance_type   = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.nw-interface1.id
    device_index = 0
  }

  key_name = "my-ec2-key"

  tags = {
    Name = "WebServer1"
  }
}

resource "aws_instance" "WebServer2" {
  ami             = "ami-06c68f701d8090592"
  instance_type   = "t2.micro"

  network_interface {
    network_interface_id = aws_network_interface.nw-interface2.id
    device_index = 0
  }

  key_name = "my-ec2-key"

  tags = {
    Name = "WebServer2"
  }
}

output "instance1_id" {
  value = aws_instance.WebServer1.id
}

output "instance2_id" {
  value = aws_instance.WebServer2.id
}

#Build a s3 storage to connect to our RDS as a back-up
resource "aws_s3_bucket" "rds_backup_bucket_jjusino" {
  bucket = "my-rds-backup-bucket-jjusino"
}

resource "aws_s3_bucket_ownership_controls" "rds_backup_bucket_jjusino" {
  bucket = aws_s3_bucket.rds_backup_bucket_jjusino.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "rds_backup_bucket_jjusino" {
  depends_on = [aws_s3_bucket_ownership_controls.rds_backup_bucket_jjusino]

  bucket = aws_s3_bucket.rds_backup_bucket_jjusino.id
  acl    = "private"
}

#Creating a policy to allow access to the s3 bucket
resource "aws_iam_role" "rds_s3_import_role" {
  name = "rds-backup-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "rds.amazonaws.com"
      },
      "Action" : "sts:AssumeRole"
    }]
  })
}

#Attaching the policy to the role
resource "aws_iam_policy" "rds_backup_policy" {
  name        = "rds-backup-policy"
  description = "Policy for RDS to access S3 for backups"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        "Resource": [
          "arn:aws:s3:::${aws_s3_bucket.rds_backup_bucket_jjusino.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.rds_backup_bucket_jjusino.bucket}/*"
        ]
      }
    ]
  })
}

#Attaching the policy to the role to RDS Instance
resource "aws_iam_role_policy_attachment" "rds_backup_policy_attach" {
  role       = aws_iam_role.rds_s3_import_role.name
  policy_arn = aws_iam_policy.rds_backup_policy.arn
}

#Creating your RDS resource hosted on AppServer1 & 2
resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "app-db-subnet-group"
  subnet_ids = [aws_subnet.AppSubnet1.id, aws_subnet.AppSubnet2.id]  

  tags = {
    Name = "AppDBSubnetGroup"
  }
}

#Creating a RDS instance with back-up capability
resource "aws_db_instance" "app_database" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0.33"  
  instance_class       = "db.t3.micro" 
  identifier           = "appdatabase"
  db_name              = "appdatabase"
  username             = "jjusino"
  password             = "db*pass123"
  skip_final_snapshot  = true
  iam_database_authentication_enabled =  true 
  publicly_accessible     = true
  db_subnet_group_name = aws_db_subnet_group.app_db_subnet_group.name
  enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]
  vpc_security_group_ids = [aws_security_group.WebTrafficSG.id]
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"
  depends_on = [ aws_iam_role_policy_attachment.rds_backup_policy_attach ]
  
  tags = {
    Name = "AppDatabase"
  }  
}

#Creating a RDS cluster with back-up capability
resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier = "rds-cluster-demo"
  engine             = "aurora-mysql"
  master_username    = "kk_labs_user_720303"
  master_password    = "password123"

  s3_import {
    ingestion_role = aws_iam_role.rds_s3_import_role.arn
    bucket_name   = aws_s3_bucket.rds_backup_bucket_jjusino.bucket
    source_engine = "mysql"
    source_engine_version = "8.0.23"
  }
}
