/*
 ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄        ▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄ 
▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░▌      ▐░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
 ▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀█░▌▐░▌░▌     ▐░▌▐░█▀▀▀▀▀▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌ ▀▀▀▀█░█▀▀▀▀ 
     ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌▐░▌▐░▌    ▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     
     ▐░▌     ▐░█▄▄▄▄▄▄▄█░▌▐░▌       ▐░▌▐░▌ ▐░▌   ▐░▌▐░▌          ▐░█▄▄▄▄▄▄▄█░▌     ▐░▌     
     ▐░▌     ▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░▌  ▐░▌  ▐░▌▐░▌          ▐░░░░░░░░░░░▌     ▐░▌     
     ▐░▌     ▐░█▀▀▀▀█░█▀▀ ▐░▌       ▐░▌▐░▌   ▐░▌ ▐░▌▐░▌          ▐░█▀▀▀▀▀▀▀█░▌     ▐░▌     
     ▐░▌     ▐░▌     ▐░▌  ▐░▌       ▐░▌▐░▌    ▐░▌▐░▌▐░▌          ▐░▌       ▐░▌     ▐░▌     
 ▄▄▄▄█░█▄▄▄▄ ▐░▌      ▐░▌ ▐░█▄▄▄▄▄▄▄█░▌▐░▌     ▐░▐░▌▐░█▄▄▄▄▄▄▄▄▄ ▐░▌       ▐░▌     ▐░▌     
▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░░▌▐░▌      ▐░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌     ▐░▌     
 ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀        ▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀         ▀       ▀      
*/

#This TF is for the Kubernetes Administration Series and includes the following setup:
/*
nix - terminal - ubuntu 18.04
subnet_consoles delta to 172.16.94.0/24 to match labs.
c1-cp1
c1-node1 .11
c1-node2 .12  
c1-node3 .13

*/

################################################Global Settings and Variables#############################################
###Standard PS AWS Setup
variable "region" {
  default = "us-west-2"

}

provider "aws" {
  version = "~> 3.0"
  region  = var.region

}
###############################################################################################

### Requires the Random Provider- creats a random string thank can server a variety of ues, s3 buckets and passwords alike.
resource "random_string" "version" {
  length  = 8
  upper   = false
  lower   = true
  number  = true
  special = false
}

resource "random_string" "user_name" {
  length  = 4
  upper   = false
  lower   = true
  number  = true
  special = false
}

resource "random_string" "password" {
  length = 16
  special = true
  min_upper = 1
  min_numeric = 1
  min_special = 1
  override_special = "!@"
}

##################################################################START PKI KEY CONFIGURATION##########################################
resource "tls_private_key" "pki" {
  algorithm   = "RSA"
  rsa_bits = "4096"
}

output "private_key_pem" {
  value  = tls_private_key.pki.private_key_pem
}

resource "local_file" "pki" {
    content     = tls_private_key.pki.private_key_pem
    filename = "$HOME/.ssh/lab-key"
    file_permission = "0600"
}

resource "aws_key_pair" "terrakey" {
  key_name   = "lab-key"
  public_key = tls_private_key.pki.public_key_openssh
}

#creating s3 instance resource 0.
resource "aws_s3_bucket" "securitylab" {
  bucket        = "securitylab-${random_string.version.result}"
  request_payer = "BucketOwner"
  tags          = {}

  versioning {
    enabled    = false
    mfa_delete = false
  }
}

resource "aws_s3_bucket_object" "privatekey" {
  key    = "lab-key"
  bucket = aws_s3_bucket.securitylab.id
  source = "$HOME/.ssh/lab-key"
  acl    = "public-read"
  depends_on = [
    local_file.pki
  ]
}
##################################################################END PKI KEY CONFIGURATION##########################################
#
#
#
##################################################################Networking Configurations##########################################
#
# Variable used in the creation of the `lab_vpc_internet_access` resource
variable "cidr_block" {
  default = "0.0.0.0/0"
}
# Custom VPC shows the use of tags to name resources
data "dns_a_record_set" "dns_addr_1" {
  host = "us-west-2.ec2.archive.ubuntu.com"
}

output "dns_addr_1" {
  value = "${data.dns_a_record_set.dns_addr_1.addrs}"
}

data "dns_a_record_set" "dns_addr_2" {
  host = "security.ubuntu.com"
}

output "dns_addr_2" {
  value = "${data.dns_a_record_set.dns_addr_2.addrs}"
}

data "dns_a_record_set" "dns_addr_3" {
  host = "apt.kubernetes.io"
}

output "dns_addr_3" {
  value = "${data.dns_a_record_set.dns_addr_3.addrs}"
}

data "dns_a_record_set" "dns_addr_4" {
  host = "packages.cloud.google.com"
}

output "dns_addr_4" {
  value = "${data.dns_a_record_set.dns_addr_4.addrs}"
}

data "dns_a_record_set" "dns_addr_5" {
  host = "docs.projectcalico.org"
}

output "dns_addr_5" {
  value = "${data.dns_a_record_set.dns_addr_5.addrs}"
}

data "dns_a_record_set" "dns_addr_6" {
  host = "dl.k8s.io"
}

output "dns_addr_6" {
  value = "${data.dns_a_record_set.dns_addr_6.addrs}"
}

data "dns_a_record_set" "dns_addr_7" {
  host = "storage-googleapis.com"
}

output "dns_addr_7" {
  value = "${data.dns_a_record_set.dns_addr_7.addrs}"
}

data "dns_a_record_set" "dns_addr_8" {
  host = "k8s.gcr.io"
}

output "dns_addr_8" {
  value = "${data.dns_a_record_set.dns_addr_8.addrs}"
}

data "dns_a_record_set" "dns_addr_9" {
  host = "kubelet.config.k8s.io"
}

output "dns_addr_9" {
  value = "${data.dns_a_record_set.dns_addr_9.addrs}"
}

data "dns_a_record_set" "dns_addr_10" {
  host = "redirect.k8s.io"
}

output "dns_addr_10" {
  value = "${data.dns_a_record_set.dns_addr_10.addrs}"
}

# Custom VPC shows the use of tags to name resources
# Instance Tenancy set to `default` is not to be confused with the concept of a Default VPC
###NETWORKING----> add subnets here within vpc scope
resource "aws_vpc" "lab_vpc" {
  cidr_block       = "172.16.0.0/16"
  enable_dns_hostnames = true
  instance_tenancy = "default"

  tags = {
    Name = "Lab VPC"
  }
}
#external security groupingfor vpc global scope
#Currently allowing all ssh in to any device...all ec2 instances are using the generated keypair.

resource "aws_security_group" "ssh_console" {
  name   = "ssh_console"
  vpc_id = aws_vpc.lab_vpc.id
#lock down to egress only to internal subnets generated in this lab! ~add to automation.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.245.222/32"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.94.0/24"]
  }

###############PINHOLES###################
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_1.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_1.addrs)
  }
#2
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_2.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_2.addrs)
  }
  #3
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_3.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_3.addrs)
  }
#4
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_4.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_4.addrs)
  }
#5
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_5.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_5.addrs)
  }



  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.94.0/24"]
  }
# For Tudor Cluster & internal guac option

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["172.16.245.223/32","52.42.34.111/32","35.162.190.211/32","52.36.220.5/32","99.69.210.192/32"]
  }

}

resource "aws_security_group" "rdp_console" {
  name   = "rdp_console"
  vpc_id = aws_vpc.lab_vpc.id
#lock down to egress only to internal subnets generated in this lab! ~add to automation.

egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.16.0.0/16"]
  }

egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.245.222/32"]
  }
 egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.94.0/24"]
  }

###############PINHOLES###################
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_1.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_1.addrs)
  }
#2
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_2.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_2.addrs)
  }
  #3
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_3.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_3.addrs)
  }
#4
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_4.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_4.addrs)
  }
#5
egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_5.addrs)
  }

egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = formatlist("%s/32",data.dns_a_record_set.dns_addr_5.addrs)
  }


  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["172.16.94.0/24"]
  }
    ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["172.16.245.223/32","52.42.34.111/32","35.162.190.211/32","52.36.220.5/32","99.69.210.192/32"]
  }

}


resource "aws_security_group" "proxy" {
  name   = "proxy_rules"
  vpc_id = aws_vpc.lab_vpc.id

#lock down to egress only to internal subnets generated in this lab! ~add to automation.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# Custom Internet Gateway - not created as part of the initialization of a VPC

resource "aws_internet_gateway" "lab_vpc_gateway" {
  vpc_id = aws_vpc.lab_vpc.id
}

# Create a Route in the Main Routing Table - no need to create a Custom Routing Table
# Use `main_route_table_id` to pull the ID of the main routing table

resource "aws_route" "lab_vpc_internet_access" {
  route_table_id         = aws_vpc.lab_vpc.main_route_table_id
  destination_cidr_block = var.cidr_block
  gateway_id             = aws_internet_gateway.lab_vpc_gateway.id
}

#proxy subnet
resource "aws_subnet" "subnet_proxy" {

  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.245.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

}

# Add a consoles subnet unless specifically required otherwise.  172.31.37-47.0


# VPC Subnet B - endpoint subnet  172.31.24.0/24
resource "aws_subnet" "subnet_consoles" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.94.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
}

# VPC Subnet B - endpoint subnet  172.31.64-74.0/24
resource "aws_subnet" "subnet_enva" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.37.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
}

#Console Subnet. Where the user engages on console or directly to the EC2. Separated from other resources intentionally.
resource "aws_subnet" "subnet_envb" {
  vpc_id                  = aws_vpc.lab_vpc.id
  cidr_block              = "172.16.64.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
}

###############################################################SSM IAM ROLE STUFF############################################################################################################


/*
     ___      .___  ___.  __   __     _______.
    /   \     |   \/   | |  | (_ )   /       |
   /  ^  \    |  \  /  | |  |  |/   |   (----`
  /  /_\  \   |  |\/|  | |  |        \   \    
 /  _____  \  |  |  |  | |  |    .----)   |   
/__/     \__\ |__|  |__| |__|    |_______/ 

*/
##############################################################EC2 Endpoint Configurations#####################################################################################################
#######################finding CURRENT AMI's for supported operating systems, does not hurt anything to leave in #############################################################################
##############################################################################################################################################################################################
data "aws_ami" "u20" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

data "aws_ami" "u18" {
  most_recent = true
  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

data "aws_ami" "u16" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

#Windows!
data "aws_ami" "w19" {
     most_recent = true     
filter {
       name   = "name"
       values = ["Windows_Server-2019-English-Full-Base-*"]  
  }     
filter {
       name   = "virtualization-type"
       values = ["hvm"]  
  }     
owners = ["801119661308"] # Canonical
}

/*
  ___ _               _    _      _   _     ___ ___ ___ 
 | _ \ |_  _ _ _ __ _| |__(_)__ _| |_| |_  | __/ __|_  )
 |  _/ | || | '_/ _` | (_-< / _` | ' \  _| | _| (__ / / 
 |_| |_|\_,_|_| \__,_|_/__/_\__, |_||_\__| |___\___/___|
                            |___/
*/                            
###############################Define EC2 INstances##################################################################################
#Include templates and then create matching template files#
#console box script
###### All template files mapped with required variables################
/*
##########SAME FOR EVERY LAB############################################################################
  ___ ___  _____      ___   ___ ___    ___ ___  _____  ____   __
 | __/ _ \| _ \ \    / /_\ | _ \   \  | _ \ _ \/ _ \ \/ /\ \ / /
 | _| (_) |   /\ \/\/ / _ \|   / |) | |  _/   / (_) >  <  \ V / 
 |_| \___/|_|_\ \_/\_/_/ \_\_|_\___/  |_| |_|_\\___/_/\_\  |_|
*/
###############PROXY TEMPLATE && PROXY EC2 #############################################################
data "template_file" "forward-proxy" {
  template = file("forward-proxy.sh")
}

# proxy boxy with tinyproxy
resource "aws_instance" "forward-proxy" {
  ami                         = data.aws_ami.u20.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.245.222"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_proxy.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.proxy.id]
  tags = {
    Name = "forward-proxy"
  }
  user_data = data.template_file.forward-proxy.rendered
  timeouts {}
}

/*
.______     _______.         _______  __    __       ___       ______ 
|   _  \   /       |        /  _____||  |  |  |     /   \     /      |
|  |_)  | |   (----` ______|  |  __  |  |  |  |    /  ^  \   |  ,----'
|   ___/   \   \    |______|  | |_ | |  |  |  |   /  /_\  \  |  |     
|  |   .----)   |          |  |__| | |  `--'  |  /  _____  \ |  `----.
| _|   |_______/            \______|  \______/  /__/     \__\ \______|
*/
#########################################################################################################################
###########################################GUACAMOLE IN AWS ENVIRONMENT##################################################
###Optional to support development#######################################################################################
#########################################################################################################################

#Guac Guac Who's There
data "template_file" "ps-guac" {
  template = file("ps-guac.sh")
  vars ={
    #guac external ip for apache.conf (lines up with http header) if you change to DNS name need to fill in dns name.
    #Have to get another way...write to file that uploads to s3? Then pull from s3. Or something else?
    #public_dns = aws_eip.ext_ip.public_dns
    #public_ip = aws_eip.ext_ip.public_ip
    #guac auth username
    guac_auth_username = "ps-student-${random_string.user_name.result}"
    #guac auth password
    guac_auth_password = "${random_string.version.result}"
    #ssh console pki private.pw
    #ssh_pki_key = tls_private_key.pki.private_key_pem
    #ssh console internal ip
    ssh_console_internal_ip = aws_instance.nix-ssh-console.private_ip
    #winrdp console pw
    win_rdp_password = "${random_string.password.result}" #returns in base64 if get_password_data is enabled
    #winrdp console internal ip
    win_rdp_internal_ip = aws_instance.win-rdp-console.private_ip
  }
}
resource "aws_instance" "ps-guac" {
  ami                         = data.aws_ami.u20.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.245.223"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_proxy.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.proxy.id]
  tags = {
    Name = "not-guac"
  }

  user_data = data.template_file.ps-guac.rendered

  timeouts {}

}


#########################################################################################
###############CONSOLES##################################################################
###############NIX SSH CONSOLE###########################################################
/*
  _  _ _____  __        ___ ___ _  _          ___ ___  _  _ ___  ___  _    ___ 
 | \| |_ _\ \/ /  ___  / __/ __| || |  ___   / __/ _ \| \| / __|/ _ \| |  | __|
 | .` || | >  <  |___| \__ \__ \ __ | |___| | (_| (_) | .` \__ \ (_) | |__| _| 
 |_|\_|___/_/\_\       |___/___/_||_|        \___\___/|_|\_|___/\___/|____|___|

*/                       

####################Conoles for user access through guacamole and main interface for lab###############################
##### Ubuntu SSH Console ##############################################################################################
#creating EC2 instance resource 0. # SCANNER INSTANCE - scanner subnet...scanner security group.

data "template_file" "nix-ssh-console" {
  template = file("nix-ssh-console.sh")
  vars ={
     # micro_webapp_ip = aws_instance.ps-t2micro-webapp.private_ip
  }
}

resource "aws_instance" "nix-ssh-console" {
  ami                         = data.aws_ami.u18.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.94.10"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_consoles.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_console.id]
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "c1-cp1"
  }
  user_data = data.template_file.nix-ssh-console.rendered
  timeouts {}

}




#####c1-node1

data "template_file" "nix-ssh-node1" {
  template = file("nix-ssh-node1.sh")
  vars ={
     # micro_webapp_ip = aws_instance.ps-t2micro-webapp.private_ip
  }
}

resource "aws_instance" "nix-ssh-node1" {
  ami                         = data.aws_ami.u18.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.94.11"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_consoles.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_console.id]
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "c1-node1"
  }
  user_data = data.template_file.nix-ssh-node1.rendered
  timeouts {}

}

###c1-node2
data "template_file" "nix-ssh-node2" {
  template = file("nix-ssh-node2.sh")
  vars ={
     # micro_webapp_ip = aws_instance.ps-t2micro-webapp.private_ip
  }
}

resource "aws_instance" "nix-ssh-node2" {
  ami                         = data.aws_ami.u18.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.94.12"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_consoles.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_console.id]
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "c1-node2"
  }
  user_data = data.template_file.nix-ssh-node2.rendered
  timeouts {}

}

###c1-node3
data "template_file" "nix-ssh-node3" {
  template = file("nix-ssh-node3.sh")
  vars ={
     # micro_webapp_ip = aws_instance.ps-t2micro-webapp.private_ip
  }
}

resource "aws_instance" "nix-ssh-node3" {
  ami                         = data.aws_ami.u18.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.16.94.13"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_consoles.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_console.id]
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "c1-node3"
  }
  user_data = data.template_file.nix-ssh-node3.rendered
  timeouts {}

}
/*#####################################################################################################
 __      _____ _  _     ___ ___  ___      ___ ___  _  _ ___  ___  _    ___ 
 \ \    / /_ _| \| |___| _ \   \| _ \___ / __/ _ \| \| / __|/ _ \| |  | __|
  \ \/\/ / | || .` |___|   / |) |  _/___| (_| (_) | .` \__ \ (_) | |__| _| 
   \_/\_/ |___|_|\_|   |_|_\___/|_|      \___\___/|_|\_|___/\___/|____|___|
*/
######################RDP Windows####################################################################

data "template_file" "win-rdp-console" {
    template = file("win-rdp-console")
    vars = {
      win_rdp_password = "${random_string.password.result}"
      guac_auth_password = "${random_string.version.result}"
    }
}

##### Windows 2019 RDP ################################################################################################
#creating EC2 instance resource MYDESKTOP

resource "aws_instance" "win-rdp-console" {
  ami                         = data.aws_ami.w19.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = true
  hibernation                 = false
  instance_type               = "t2.medium"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.subnet_consoles.id #subnet is allowed rdp inbound and to access other devices.
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.rdp_console.id]
  user_data                   = data.template_file.win-rdp-console.rendered
  #iam_instance_profile = aws_iam_instance_profile.ssm_profile.name
  tags = {
    Name = "win-rdp-console"
  }

  timeouts {}

}

###########################################################################################################################
#######################################################

###########################################Environment Applications and Devices############################
/*
#creating EC2 instance resource 1.
resource "aws_instance" "ps-t2micro-webapp" {
  ami                         = data.aws_ami.u18.id
  associate_public_ip_address = true
  disable_api_termination     = false
  ebs_optimized               = false
  get_password_data           = false
  hibernation                 = false
  instance_type               = "t2.medium"
  private_ip                  = "172.31.37.55"
  ipv6_address_count          = 0
  ipv6_addresses              = []
  monitoring                  = false
  subnet_id                   = aws_subnet.lab_vpc_subnet_a.id
  key_name                    = aws_key_pair.terrakey.key_name
  vpc_security_group_ids      = [aws_security_group.ssh.id]
  user_data                   = data.template_file.ps-t2micro-webapp.rendered
  tags = {
    Name = "Web-01"
  }


  timeouts {}

}
*/
################################################### Dump file or information #######################################
/*

 __   ___   ___ ___   _   ___ _    ___    ___  _   _ _____ ___ _   _ _____ 
 \ \ / /_\ | _ \_ _| /_\ | _ ) |  | __|  / _ \| | | |_   _| _ \ | | |_   _|
  \ V / _ \|   /| | / _ \| _ \ |__| _|  | (_) | |_| | | | |  _/ |_| | | |  
   \_/_/ \_\_|_\___/_/ \_\___/____|___|  \___/ \___/  |_| |_|  \___/  |_|  
                                                                         
*/

############# nix ssh console outputs and files##########
#
#
#########################################################
#not sure if this is still useful
output "ssh_instance_id" {
  value       = aws_instance.nix-ssh-console.id
  description = "nix console 1 instance id"
}

#box name
output "nix-ssh-1-name" {
  value       = "C1-CP1"
}
#file
resource "local_file" "nix-ssh-console-1-name" {
  content       = "Ubuntu #1"
  filename    = "connections/1-nix-ssh-console/name"
}

#box protocol
#box name
output "nix-ssh-1-protocol" {
  value       = "ssh"
}
#file
resource "local_file" "nix-ssh-console-1-protocol" {
  content       = "ssh"
  filename    = "connections/1-nix-ssh-console/protocol"
}


#DNS 
output "nix-ssh-console-1-dns" {
  value       = aws_instance.nix-ssh-console.public_dns
  description = "DNS for the ssh console"
}
#file
resource "local_file" "nix-ssh-console-1-dns" {
    content     = aws_instance.nix-ssh-console.public_dns
    filename = "connections/1-nix-ssh-console/hostname"
    #file_permission = "0600"
}
#extip
output "nix-ssh-console-1-extip" {
  value       = aws_instance.nix-ssh-console.public_ip
  description = "External IP of #1 Nix SSH Console"
}
#file
resource "local_file" "nix-ssh-console-1-extip" {
    content     = aws_instance.nix-ssh-console.public_ip
    filename = "connections/1-nix-ssh-console/extip"
    #file_permission = "0600"
}
#port
#extip
output "nix-ssh-console-1-port" {
  value       = "22"
  description = "Port of #1 Nix SSH Console"
}
#file
resource "local_file" "nix-ssh-console-1-port" {
    content     = "22"
    filename = "connections/1-nix-ssh-console/port"
    #file_permission = "0600"
}
#username
output "nix-ssh-console-1-un" {
  value       = "ubuntu"
  description = "Ubuntu ami username is ubuntu."
}
#file
resource "local_file" "nix-ssh-console-1-un" {
    content     = "ubuntu"
    filename = "connections/1-nix-ssh-console/username"
    #file_permission = "0600"
}
#ssh private key
resource "local_file" "pki-1-ssh" {
    content     = tls_private_key.pki.private_key_pem
    filename = "connections/1-nix-ssh-console/private-key"
    #file_permission = "0600"
}

############################################## win rdp outputs and files#################################################################################
################################################################################################################################
#instance id
output "rdp_instance_id" {
  value       = aws_instance.win-rdp-console.id
}

#box name
output "win-rdp-1-name" {
  value       = "Windows 2019 #1"
}
#file
resource "local_file" "win-rdp-console-1-name" {
  content       = "Windows 2019 #1"
  filename    = "connections/2-win-rdp-console/name"
}

#box protocol
#box name
output "win-rdp-1-protocol" {
  value       = "rdp"
}
#file
resource "local_file" "win-rdp-console-1-protocol" {
  content       = "rdp"
  filename    = "connections/2-win-rdp-console/protocol"
}

#DNS
output "win-rdp-console-1-dns" {
  value       = aws_instance.win-rdp-console.public_dns
  description = "Public DNS for the #2 WIN RDP console"
}
#file
resource "local_file" "win-rdp-console-1-dns" {
    content     = aws_instance.win-rdp-console.public_dns
    filename = "connections/2-win-rdp-console/hostname"
    #file_permission = "0600"
}

#extip
output "win-rdp-console-1-extip" {
  value       = aws_instance.win-rdp-console.public_ip
  description = "connections/#2 Windows RPD public IP"
}
#file
resource "local_file" "win-rdp-console-2-extip" {
    content     = aws_instance.win-rdp-console.public_ip
    filename = "connections/2-win-rdp-console/extip"
    #file_permission = "0600"
}
#extip
output "win-rdp-console-2-port" {
  value       = "3389"
  description = "Port of #2 win RDP Console"
}
#file
resource "local_file" "win-rdp-console-2-port" {
    content     = "3389"
    filename = "connections/2-win-rdp-console/port"
    #file_permission = "0600"
}
#Username
output "win-rdp-console-2-un" {
  value       = "administrator"
  description = "Windows UN are Administrator."
}
#file
resource "local_file" "win-rdp-console-2-un" {
    content     = "administrator"
    filename = "connections/2-win-rdp-console/username"
    #file_permission = "0600"
}

#Password for WIN
output "win-rdp-console-2-pw" {
  value       = random_string.password.result
  description = "Password for the windows devices."
}
#file
resource "local_file" "win-rdp-console-2-pw" {
    content     = random_string.password.result
    filename = "connections/2-win-rdp-console/password"
    #file_permission = "0600"
}
#nla security param
resource "local_file" "win-rdp-console-2-nla" {
    content     = "nla"
    filename = "connections/2-win-rdp-console/security"
    #file_permission = "0600"
}
# ignor-cert
resource "local_file" "win-rdp-console-2-cert" {
    content     = "true"
    filename = "connections/2-win-rdp-console/ignore-cert"
    #file_permission = "0600"
}

################################################### Dump file or information #######################################

#guac auth username
resource "local_file" "guac_auth_un" {
    content     = "ps-student-${random_string.user_name.result}"
    filename = "guac-auth-username.txt"
}

#guac auth password
resource "local_file" "guac_auth_pw" {
    content     = random_string.version.result
    filename = "guac-auth-password.txt"
}

#guac auth dns 
resource "local_file" "guac_dns" {
    content     = "http://${aws_instance.ps-guac.public_dns}"
    filename = "guac-dnsname.txt"
}

output "lab_username" {
  value       = "ps-student-${random_string.user_name.result}"
  description = "Student Username for Lab"
}

output "lab_password" {
  value       = "${random_string.version.result}"
  description = "Student Password for Lab"
}

output "lab_url_link" {
  value       = "http://${aws_instance.ps-guac.public_dns}"
  description = "Public URL for lab."
}

#alltogether
output "all_the_way" {
  value       = "http://${aws_instance.ps-guac.public_dns}/#/?username=ps-student-${random_string.user_name.result}&password=${random_string.version.result}"
}

#EOL
