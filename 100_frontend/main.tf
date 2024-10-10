#creating,configuring the frontend server as an ec2 instance and then applying autoscaling as well :
#Created frontend server as ec2_instance
module "frontend" {
    source = "terraform-aws-modules/ec2-instance/aws"

    name = local.resource_name

    ami = local.ami
    instance_type = "t3.micro"
    vpc_security_group_ids = [local.frontend_sg_id]
    subnet_id = local.private_subnet_ids

    tags = merge(
        var.common_tags,
        var.frontend_tags,
        {
            Name = local.resource_name
        }
    )
}

#Configuring the frontend server using ansible playbook.
# Here Variables are define in terraform and will be pushed/used in shell(frontend.sh), then from shell to ansible.

resource "null_resource" "frontend" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {       #Whenver module.frontend id changes (means any version change in frontend application,) then null_resource triggers this instance id to execute the frontend.sh in shell
    instance_id = module.frontend.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host = module.frontend.private_ip  #Connecting to remote server which is frontend server via its private_ip
    user = "ec2-user"
    password = "DevOps321"
    type = "ssh"
  }


  #Copying the frontend.sh file into frontend server /tmp folder from local(laptop where this code and terraform is installed)
  provisioner "file" {
    source = "${var.frontend_tags.Component}.sh"   
    destination = "/tmp/frontend.sh"  #this is inside the frontend application server
  }

  #executing the frontend.sh inside the frontend server
  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/frontend.sh",
      "sudo sh /tmp/frontend.sh ${var.frontend_tags.Component} ${var.environment}"  #sudo sh file_name.sh $1 == var.frontend_tags.Component, $2 == var.environment. These arguments from Terraform ---> shell
    ]
  }
}

#After the frontend application is configured, perform health check by using below:
/* curl localhost:8080/health
curl -I localhost:8080/health - It will give you below output:
HTTP/1.1 200 OK
X-Powered-By: Express
Access-Control-Allow-Origin: *
Content-Type: application/json; charset=utf-8
Content-Length: 26
ETag: W/"1a-QZ+7SSwm/0jnTs4ZUIg8XKGjY80"
Date: Wed, 09 Oct 2024 12:04:13 GMT
Connection: keep-alive
Keep-Alive: timeout=5 */


#Now stop the instance to take AMI from it:
resource "aws_ec2_instance_state" "frontend" {
  instance_id = module.frontend.id
  state       = "stopped"
  depends_on = [null_resource.frontend]
}

#Taking AMI From the instance:
resource "aws_ami_from_instance" "frontend" {
  name               = local.resource_name
  source_instance_id = module.frontend.id
  depends_on = [aws_ec2_instance_state.frontend]
}


#Terminate the created instance as AMI is taken already:
resource "null_resource" "frontend_delete" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {       #Whenver module.frontend id changes (means any version change in frontend application,) then null_resource triggers this instance id to execue the frontend.sh in shell
    instance_id = module.frontend.id
  }

 
  provisioner "local-exec" {  #as now it is inside the server, henve provisioning as local exec
    command = "aws ec2 terminate-instances --instance-ids ${module.frontend.id}"   #This is aws cli command to terminate instances
  }

  depends_on = [aws_ami_from_instance.frontend]
}

#Now creating target group resource:
resource "aws_lb_target_group" "frontend" {
  name     = local.resource_name
  port     = 8080    #This target group will get triggered when load balncer sends requests of 8080 port having protocol HTTP, it will send to frontend application /its listener
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path = "/health"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 5
    timeout = 4   #timeout must be less than the interval
    matcher = "200-299"
    protocol = "HTTP"

  }
}

#Creating Launch Template:
resource "aws_launch_template" "frontend" {   #To create auto-scaling we need to provide either launch_template or launch_configuration or mixed_instances_policy
  name = local.resource_name

  image_id = aws_ami_from_instance.frontend.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  vpc_security_group_ids = [local.frontend_sg_id]
  update_default_version = true  #version should be latest

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name
    }
  }


}  #here subnet id is not provided, as we provided in below auto scaling

#Create auto-scaling using launch template in target group:
resource "aws_autoscaling_group" "frontend" {
  name     = local.resource_name
  
  max_size                  = 10 #till 10 instances will be created using this autoscaling
  min_size                  = 2 #min size using this autoscaling is 2 instances
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2  #starting of autoscaling group with 2 instances
  #force_delete              = true
  target_group_arns = [aws_lb_target_group.frontend.arn]

  launch_template {  #as we used launch template instead of using launch configuration and mixed-instances policy
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  vpc_zone_identifier       = [local.private_subnet_ids]


  
  

  tag {
    key                 = "Name"
    value               = local.resource_name
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m" #Means if it didn't get health check/ if it is unhealthy from instance within 15 min then autoscaling will delete that instance
  }

  tag {
    key                 = "project"
    value               = "expense"
    propagate_at_launch = false
  }
}


#creating auto scaling group policy:

resource "aws_autoscaling_policy" "example" {

  autoscaling_group_name = aws_autoscaling_group.frontend.name
  name                   = "${local.resource_name}-autoscaling-policy"
  policy_type            = "TargetTrackingScaling"
  

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0  #This can be CPU Utilization, memory utilization, if exceeds 70% then this policy will trigger autoscaling group based on max and min size it will create instances
  }
}

#Creating listener_rule record for frontend application  ----> frontend.app-dev.zone_name
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.frontend.arn
  priority     = 100  #can be 1 - 50000, low priority will be evaluated first.

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  
  condition {
    host_header {
      values = ["${var.frontend_tags.Component}.app-${var.environment}.var.zone_name"]  #frontend.app-dev.mohansai.online
    }
  }
}





