# Create Provider block
provider "aws" {
    region = var.AWS_REGION
    access_key = "MyIAMAccessKey"
    secret_key = "MyIAMSecretKey"
}

# Create AWS VPC
resource "aws_vpc" "terraform_vpc_01" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "terraform_vpc_01"
        Project = "terraform_sodba_01"
    }
 }

# Create AWS Subnets
resource "aws_subnet" "public_subnets" {
    count = length(var.PUBLIC_SUBNET_CIDRS)
    vpc_id = aws_vpc.terraform_vpc_01.id
    cidr_block = element(var.PUBLIC_SUBNET_CIDRS, count.index)
    availability_zone = element(var.AWS_AZS, count.index)
    tags = {
        Name = "public_subnet_${count.index + 1}"
        Project = "terraform_sodba_01"
    }
}

resource "aws_subnet" "private_subnets" {
    count = length(var.PRIVATE_SUBNET_CIDRS)
    vpc_id = aws_vpc.terraform_vpc_01.id
    cidr_block = element(var.PRIVATE_SUBNET_CIDRS, count.index)
    availability_zone = element(var.AWS_AZS, count.index)
    tags = {
        Name = "private_subnet_${count.index + 1}"
        Project = "terraform_sodba_01"
    }
}

# Create AWS Internet Gateway
resource "aws_internet_gateway" "terraform_igw_01" {
    vpc_id = aws_vpc.terraform_vpc_01.id
    tags = {
        Name = "terraform_igw_01"
        Project = "terraform_sodba_01"
    }
}

# Create AWS Route Table
resource "aws_route_table" "terraform_public_rt_01" {
    vpc_id = aws_vpc.terraform_vpc_01.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.terraform_igw_01.id
    }
    tags = {
        Name = "terraform_public_rt_01"
        Project = "terraform_sodba_01"
    }
}

resource "aws_route_table_association" "public_subnet_asso" {
    count = length(var.PUBLIC_SUBNET_CIDRS)
    subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
    route_table_id = aws_route_table.terraform_public_rt_01.id
}

# Create AWS Security Group
resource "aws_security_group" "terraform_sg_01" {
    name = "terraform_sg_01"
    vpc_id = aws_vpc.terraform_vpc_01.id
    egress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]

    }
    
    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Project = "terraform_sodba_01"
    }
}

# Create AWS public instance
resource "aws_instance" "terraform_instance_01" {
    ami = var.AWS_AMIS[var.AWS_REGION]
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnets[0].id
    vpc_security_group_ids = [aws_security_group.terraform_sg_01.id]
    key_name = "sodbaveKey"
    metadata_options {
        http_tokens = "optional"
    }
    associate_public_ip_address = true

    user_data = <<-EOF
                    #!/bin/bash
                    yum update -y 2>&1 > /home/ec2-user/boot.txt
                    yum install -y httpd 2>&1 >> /home/ec2-user/boot.txt
                    /bin/systemctl enable httpd.service
                    /bin/systemctl start httpd.service
                    /bin/systemctl status httpd.service 2>&1 >> /home/ec2-user/boot.txt
                    EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                    echo "EC2_AVAIL_ZONE = $EC2_AVAIL_ZONE" 2>&1 >> /home/ec2-user/boot.txt
                    echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
                EOF

    tags = {
        Name = "terraform_instance_01"
        Project = "terraform_sodba_01"
    }
}

# Create AWS Load Balancer
resource "aws_alb" "terraform_alb_01" {
    name = "terraform-alb-01"
    security_groups = [
        "${aws_security_group.terraform_sg_01.id}"
    ]
    subnets = [
        "${aws_subnet.private_subnets[0].id}",
        "${aws_subnet.private_subnets[1].id}",
        "${aws_subnet.private_subnets[2].id}"
    ]
    enable_cross_zone_load_balancing = true
    #load_balancer_type = "application"
    tags = {
        Project = "terraform_sodba_01"
    }
}

# Configure the target group
resource "aws_alb_target_group" "terraform_tg_01" {
    name     = "http"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.terraform_vpc_01.id
    health_check {
        port     = 80
        protocol = "HTTP"
    }
    lifecycle {
        create_before_destroy = true
    }
}

# Configure the listener
resource "aws_alb_listener" "terraform_listener_01" {
    load_balancer_arn = aws_alb.terraform_alb_01.arn
    port = "80"
    protocol = "HTTP"
    default_action {
        target_group_arn = aws_alb_target_group.terraform_tg_01.arn
        type = "forward"
    }
}

# Create AWS Launch configuration
resource "aws_launch_configuration" "terraform_lc_01" {
    #name_prefix = "terraform_web_"
    name = "terraform_lc_01"
    image_id = var.AWS_AMIS[var.AWS_REGION] 
    instance_type = "t2.micro"
    key_name = "sodbaveKey"
    security_groups = [ "${aws_security_group.terraform_sg_01.id}" ]

    metadata_options {
        http_tokens = "optional"
    }

    user_data = <<-EOF
                    #!/bin/bash
                    yum update -y 2>&1 > /home/ec2-user/boot.txt
                    yum install -y httpd 2>&1 >> /home/ec2-user/boot.txt
                    /bin/systemctl enable httpd.service
                    /bin/systemctl start httpd.service
                    /bin/systemctl status httpd.service 2>&1 >> /home/ec2-user/boot.txt
                    EC2_AVAIL_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
                    echo "EC2_AVAIL_ZONE = $EC2_AVAIL_ZONE" 2>&1 >> /home/ec2-user/boot.txt
                    echo "<h1>Hello World from $(hostname -f) in AZ $EC2_AVAIL_ZONE </h1>" > /var/www/html/index.html
                EOF

    lifecycle {
        create_before_destroy = true
    }
}

# Create AWS Auto Scaling Group
resource "aws_autoscaling_group" "terraform_asg_01" {
    name = "${aws_launch_configuration.terraform_lc_01.name}_asg_instance"  
    min_size = 1
    desired_capacity = 1
    max_size = 1
    health_check_type = "EC2"
    depends_on = [
        aws_alb.terraform_alb_01,
    ]
    launch_configuration = "${aws_launch_configuration.terraform_lc_01.name}"
    enabled_metrics = [
        "GroupMinSize",
        "GroupMaxSize",
        "GroupDesiredCapacity",
        "GroupInServiceInstances",
        "GroupTotalInstances"
    ]
    metrics_granularity = "1Minute"
    termination_policies = [
        "OldestInstance",
        "OldestLaunchConfiguration",
    ]
    vpc_zone_identifier  = [
        "${aws_subnet.private_subnets[0].id}",
        "${aws_subnet.private_subnets[1].id}",
        "${aws_subnet.private_subnets[2].id}"
    ]
    target_group_arns = [
        "${aws_alb_target_group.terraform_tg_01.arn}",
    ]

  # Required to redeploy without an outage.
    lifecycle {
        create_before_destroy = true
    }
    tag {
        key                 = "Name"
        value               = "terraform_asg_01"
        propagate_at_launch = true
    }
}

