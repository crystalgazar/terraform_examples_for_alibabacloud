variable "project_name" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}
variable "password" {}
variable "publickey" {}
variable "database_user_name" {}
variable "database_user_password" {}
variable "database_name" {}
variable "database_character" {}

# Alicloud Providerの設定
provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# Create a new load balancer for classic
resource "alicloud_slb" "slb" {
  name                 = "${var.project_name}-slb"
  internet             = true
  internet_charge_type = "paybytraffic"

  listener = [
    {
      "instance_port" = "80"
      "lb_port"       = "80"
      "lb_protocol"   = "http"
      "bandwidth"     = "10"
      "sticky_session" = "on"
      "sticky_session_type" = "insert"
      "cookie_timeout" = "1"
      "health_check"  = "on"
      "health_check_type" = "http"
      "health_check_connect_port" = "80"
      "health_check_domain" = "$_ip"
      "health_check_uri" = "/"
      "health_check_http_code" = "http_2xx"
      "health_check_timeout" = "5"
      "health_check_interval" = "5"
      "healthy_threshold" = "3"
      "unhealthy_threshold" = "3"
    }
  ]
}

resource "alicloud_slb_attachment" "slb_attachment" {
    slb_id    = "${alicloud_slb.slb.id}"
    instances = ["${alicloud_instance.web.*.id}"]
}

resource "alicloud_security_group" "sg_wordpress" {
  name   = "${var.project_name}-sg-wordpress"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "wordpress_allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg_wordpress.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "wordpress_allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg_wordpress.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group" "sg_db" {
  name   = "${var.project_name}-sg-db"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "db_allow_mysql" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "3306/3306"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg_db.id}"
  cidr_ip           = "0.0.0.0/0"
}

# VPCの作成
resource "alicloud_vpc" "vpc" {
  name = "${var.project_name}-vpc"
  cidr_block = "192.168.0.0/16"
}

# vswitchの作成。VPCの中に作ります。
resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/24"
  availability_zone = "${var.zone}"
}

# ECSの作成
resource "alicloud_instance" "web" {
  count = 2
  instance_name = "${var.project_name}-ecs-web${count.index}"
  host_name = "wordpress-ecs-web${count.index}"
  availability_zone = "${var.zone}"
  image_id = "centos_7_3_64_40G_base_20170322.vhd"
  instance_type = "ecs.n4.small"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg_wordpress.id}"]
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  user_data = "#!/bin/bash\necho \"${var.publickey}\" > /tmp/publickey\n${file("provisioning_wordpress.sh")}"
  password = "${var.password}"
  internet_charge_type = "PayByTraffic"
  internet_max_bandwidth_out = 1
}

resource "alicloud_instance" "db" {
  instance_name = "${var.project_name}-ecs-db"
  host_name = "wordpress-ecs-db"
  availability_zone = "${var.zone}"
  image_id = "m-t4n48ovneudixf3acvvx"
  instance_type = "ecs.n4.small"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg_db.id}"]
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  password = "${var.password}"
}