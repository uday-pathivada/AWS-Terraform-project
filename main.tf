resource "aws_vpc" "vpc_terraform" {
    cidr_block = var.ci
}

resource "aws_subnet" "sub1" {
    vpc_id = aws_vpc.vpc_terraform.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
    vpc_id = aws_vpc.vpc_terraform.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "connect" {
    vpc_id = aws_vpc.vpc_terraform.id
}

resource "aws_route_table" "RT" {
    vpc_id = aws_vpc.vpc_terraform.id
    route{
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.connect.id
    }
  
}

resource "aws_route_table_association" "rta_1" {
    subnet_id = aws_subnet.sub1.id
    route_table_id = aws_route_table.RT.id
  
}

resource "aws_route_table_association" "rta_2" {
    subnet_id = aws_subnet.sub2.id
    route_table_id = aws_route_table.RT.id
  
}

resource "aws_security_group" "web_sg"{
  name        = "web_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc_terraform.id

  tags = {
    Name = "web_sg"
}
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_s3_bucket" "example" {
    bucket = "uniq_name_for_s3"
  
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.example.id
  acl    = "public-read"
}

resource "aws_instance" "webserver_1" {
    ami = "ami-0a1b648e2cd533174"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.web_sg.id]
    subnet_id = aws_subnet.sub1.id
    user_data = base64encode(file("userdata.sh"))
  
}

resource "aws_instance" "webserver_2" {
    ami = "ami-0a1b648e2cd533174"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.web_sg.id]
    subnet_id = aws_subnet.sub2.id
    user_data = base64encode(file("userdata_1.sh"))
  
}

resource "aws_lb" "mylb" {
    name = "mylb"
    internal = false
    load_balancer_type = "application"

    security_groups = [aws_security_group.web_sg.id]
    subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

    tags = {
      Name = "web"
    }
}

resource "aws_lb_target_group" "tg" {
    name = "myTG"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.vpc_terraform.id

    health_check {
      path = "/"
      port = "traffic-port"
    }
}

resource "aws_lb_target_group_attachment" "attach1" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver_1.id
    port = 80
  
}

resource "aws_lb_target_group_attachment" "attach2" {
    target_group_arn = aws_lb_target_group.tg.arn
    target_id = aws_instance.webserver_2.id
    port = 80
}


resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.mylb.arn
    port = 80
    protocol = "HTTP"
    default_action {
      target_group_arn = aws_lb_target_group.tg.arn
      type = "forward"
    }
  
}

output "loadbalancerdns" {
    value = aws_lb.mylb.dns_name
  
}
