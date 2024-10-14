#creating,configuring the backend server as an ec2 instance and then applying autoscaling as well :
#Created backend server as ec2_instance
module "backend" {
    source = "terraform-aws-modules/ec2-instance/aws"

    name = local.resource_name

    ami = local.ami
    instance_type = "t3.micro"
    vpc_security_group_ids = [local.backend_sg_id]
    subnet_id = local.private_subnet_ids

    tags = merge(
        var.common_tags,
        var.backend_tags,
        {
            Name = local.resource_name
        }
    )
}

#Configuring the backend server using ansible playbook.
# Here Variables are define in terraform and will be pushed/used in shell(backend.sh), then from shell to ansible.

resource "null_resource" "backend" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {       #Whenver module.backend id changes (means any version change in backend application,) then null_resource triggers this instance id to execute the backend.sh in shell
    instance_id = module.backend.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host = module.backend.private_ip  #Connecting to remote server which is backend server via its private_ip
    user = "ec2-user"
    password = "DevOps321"
    type = "ssh"
  }


  #Copying the backend.sh file into backend server /tmp folder from local(laptop where this code and terraform is installed)
  provisioner "file" {
    source = "${var.backend_tags.Component}.sh"   
    destination = "/tmp/backend.sh"  #this is inside the backend application server
  }

  #executing the backend.sh inside the backend server
  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/backend.sh",
      "sudo sh /tmp/backend.sh ${var.backend_tags.Component} ${var.environment}"  #sudo sh file_name.sh $1 == var.backend_tags.Component, $2 == var.environment. These arguments from Terraform ---> shell
    ]
  }
}

# #After the backend application is configured, perform health check by using below:
# /* curl localhost:8080/health
# curl -I localhost:8080/health - It will give you below output:
# HTTP/1.1 200 OK
# X-Powered-By: Express
# Access-Control-Allow-Origin: *
# Content-Type: application/json; charset=utf-8
# Content-Length: 26
# ETag: W/"1a-QZ+7SSwm/0jnTs4ZUIg8XKGjY80"
# Date: Wed, 09 Oct 2024 12:04:13 GMT
# Connection: keep-alive
# Keep-Alive: timeout=5 */


#Now stop the instance to take AMI from it:
resource "aws_ec2_instance_state" "backend" {
  instance_id = module.backend.id
  state       = "stopped"
  depends_on = [null_resource.backend]
}

#Taking AMI From the instance:
resource "aws_ami_from_instance" "backend" {
  name               = local.resource_name
  source_instance_id = module.backend.id
  depends_on = [aws_ec2_instance_state.backend]
}


#Terminate the created instance as AMI is taken already:
resource "null_resource" "backend_delete" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {       #Whenver module.backend id changes (means any version change in backend application,) then null_resource triggers this instance id to execue the backend.sh in shell
    instance_id = module.backend.id
  }

 
  provisioner "local-exec" {  #as now it is inside the server, henve provisioning as local exec
    command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"   #This is aws cli command to terminate instances
  }

  depends_on = [aws_ami_from_instance.backend]
}

#Now creating target group resource:
resource "aws_lb_target_group" "backend" {
  name     = local.resource_name
  port     = 8080    #This target group will get triggered when load balncer sends requests of 8080 port having protocol HTTP, it will send to backend application /its listener
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
resource "aws_launch_template" "backend" {   #To create auto-scaling we need to provide either launch_template or launch_configuration or mixed_instances_policy
  name = local.resource_name

  image_id = aws_ami_from_instance.backend.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  vpc_security_group_ids = [local.backend_sg_id]
  update_default_version = true  #version should be latest

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = local.resource_name
    }
  }


}  #here subnet id is not provided, as we provided in below auto scaling

#Create auto-scaling using launch template in target group:
resource "aws_autoscaling_group" "backend" {
  name     = local.resource_name
  
  max_size                  = 10 #till 10 instances will be created using this autoscaling
  min_size                  = 2 #min size using this autoscaling is 2 instances
  health_check_grace_period = 60 #health check to be performed after how many seconds of instance creation
  health_check_type         = "ELB"
  desired_capacity          = 2  #starting of autoscaling group with 2 instances
 /*  how it works:
  # first scaling event == (2 initial + 2 from scaling event)
  # second scaling event == 4 current + 2 additional(min.desired) = 6 instances */

  #force_delete              = true
  target_group_arns = [aws_lb_target_group.backend.arn]  #auto scaling will create targets(new ec2 instances/backend servers) in backend target group

  launch_template {  #as we used launch template instead of using launch configuration and mixed-instances policy
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  vpc_zone_identifier       = [local.private_subnet_ids]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50  #When launch_template is changed then that triggers this to perform rolling by maintaining min_healthy_percentage as 50, means let say there are 10 servers(ec2 instances), if launch template changes it will triggers this rolling, then rolling will refresh 50% means 5 instances only(means will create new 5 ec2 instances, once these are up, it will delete old 5 instances) as a batch keeping remaining 5 instances operational so that there will be now downtime for the applications, once this 5 is completed, it performs for other remaining 5 instances in fresh another batch

    }
    triggers = ["launch_template"]
  }


  
  

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

  autoscaling_group_name = aws_autoscaling_group.backend.name
  name                   = "${local.resource_name}-autoscaling-policy"
  policy_type            = "TargetTrackingScaling"
  

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0  #This is average of all current instances - can be CPU Utilization, memory utilization, if exceeds 70% then this policy will trigger autoscaling group based on max and min size it will create instances
  }
}

#Creating listener_rule record for backend application  ----> backend.app-dev.zone_name
resource "aws_lb_listener_rule" "backend" {
  listener_arn = local.app_alb_listener_arn
  priority     = 100  #for a single listener, can be many listener rules, can be 1 - 50000, low priority will be evaluated first.

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  
  condition {
    host_header {
      values = ["${var.backend_tags.Component}.app-${var.environment}.${var.zone_name}"]  #backend.app-dev.mohansai.online  ---> forward this request to backend target grouptowards backend application
    }
  }
}

/* # differen rules from single backend load balancer
# in above condition, url configured is backend.app-dev.mohansai.online this is achieved by listener rule, but load balancer is *.app-dev.mohansai.online
# in future we can create many rules example as below:
# something.app-dev.mohansai.online
# devops.app-dev.mohansai.online
# picture.app-dev.mohansai.online */





