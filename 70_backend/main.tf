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
  triggers = {       #Whenver module.backend id changes (means any version change in backend application,) then null_resource triggers this instance id to execue the backend.sh in shell
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

#After the backend application is configured, perform health check by using below:
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
resource "aws_ec2_instance_state" "backend" {
  instance_id = module.backend.id
  state       = "sto"
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
  port     = 8080
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


