module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "expense"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name  = "transactions"
  username = "root"
  port     = "3306"
  password = "ExpenseApp1"
  manage_master_user_password = false  #we informed that AWS Should not manage this user_password


  
  vpc_security_group_ids = [local.mysql_sg_id]


  tags = merge(
    var.common_tags,
    var.rds_tags,
    
  )

  # DB parameter group
  family = "mysql8.0"

  #db subnet group
  db_subnet_group_name = local.database_subnet_group_name

  # DB option group
  major_engine_version = "8.0"

  # enable_deletion_protection = false #if it is set to true then db cannot be deleted.  This should be placed for load balancer
  # for rds, argument is deletion_protection = false

  skip_final_snapshot = true

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}




#creating rds expense db's endpoint as expense-dev.mohansai.online
# as mysql-dev.mohansai.online points to rds db endpoint == module.db.db_instance_address

module "records" {
    source = "terraform-aws-modules/route53/aws//modules/records"

    zone_name = var.zone_name

    records = [
        {
            type = "CNAME"
            ttl = 1
            name = "mysql-${var.environment}"
            records = [
                module.db.db_instance_address  #It will give rds db Endpoint which was create by AWS RDS with given above inputs

            ]
            allow_overwrite = true

        },
        
    ]
    
}

