#! /bin/bash

#timesyncd attempts to reach out to ntp.ubuntu.com but hangs because it gets not response, this will speed up overall loadtime.
systemctl stop systemd-timesyncd
systemctl disable systemd-timesyncd


#standard proxy ready check before attempts to install #####################################################################################################
echo "begin proxy test" >> script.test
response=\$$(sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 curl --write-out '%%{http_code}' --silent --output /dev/null www.google.com)
while [ \$$response -ne "200" ]; do
    echo \$$response >> script.test
    sleep 10
    response=\$$(sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 curl --write-out '%%{http_code}' --silent --output /dev/null www.google.com)
done
############################################################################################################################################################

echo "success1">> ~/peaceinourtime
# Update repo
sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 apt update

# In this solution this can remain until the end when it needs to be uninstalled.
sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 apt -y install ec2-instance-connect

# Install guac dependencies - list here has been validated to support all required guac capabilites 1-26-2021 AES
sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 DEBIAN_FRONTEND=noninteractive apt -y --force-yes install build-essential libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libvncserver-dev freerdp2-dev libssh2-1-dev libtelnet-dev libwebsockets-dev libpulse-dev libvorbis-dev libwebp-dev libssl-dev libpango1.0-dev libswscale-dev libavcodec-dev libavutil-dev libavformat-dev git

#standard github project pull pull can be replaced with pluralsights github

sudo git -c http.proxy="http://tstark:pssecrocks@172.16.245.222:8888" clone https://github.com/arosenmund/ps-newterra-poc.git /home/ubuntu/ps-newterra-poc
#update to use same github as the project so we can have a custom usermapping file with variables that are consistently replaced.  Not the final solution, need to switchup after making modular solution...maybe generate xml file with creator

# download gucamole server
sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 wget https://mirrors.sonic.net/apache/guacamole/1.3.0/source/guacamole-server-1.3.0.tar.gz
tar -xvf guacamole-server-1.3.0.tar.gz

#move it so you know where it is, commands run as root in "/" always us absolute references
sudo mv guacamole-server-1.3.0 /opt/guacamole-server
sudo autoreconf -vfi
cd /opt/guacamole-server #watch this, the cwd may not operate properly here
sudo ./configure --with-init-dir=/etc/init.d
sudo make

### IT IS VERY LIKEY I WILL SIMPLY DOWNLOAD FROM THIS POINT, ALREADY COMPILED ON A UBUNTU 20.04 SYSTEM###Need to test the speed.

sudo make install
sudo ldconfig
sudo systemctl daemon-reload
sudo systemctl start guacd
sudo systemctl enable guacd



############NEED APACHE TOMCAT APPLLET WAR############

#Install Apache Tomcat

sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 apt -y install tomcat9 tomcat9-admin tomcat9-common tomcat9-user
#This auto starts and is listenting on port 8080  check with sudo ss -lnpt | grep java


# Download the already compiled war file for the 1.3 client and move to /var/kib/tomcat9/webapps

sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 wget https://mirror.olnevhost.net/pub/apache/guacamole/1.3.0/binary/guacamole-1.3.0.war

# Future capability for "single click" will require the use of the header authentication module that will need to be added to an "extensions folder"  

sudo mv guacamole-1.3.0.war /var/lib/tomcat9/webapps/guacamole.war

sudo systemctl restart tomcat9 guacd

# Configure guacamole 
sudo mkdir /etc/guacamole/
#guacamole.properties is already configured
sudo mv /home/ubuntu/ps-newterra-poc/configs/guacamole.properties /etc/guacamole/guacamole.properties

##Configure user-mapping.xml befor moving to /etc/guacamole

#var guac auth username (from randstring gen-un)
sed 's/@guac_auth_username@/${guac_auth_username}/' -i /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml


#var guac auth password (from randstring gen-pw)
sed 's/@guac_auth_password@/${guac_auth_password}/' -i /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml

#var pki key for ssh un is ubuntu for u20
#get key
sudo wget https://securitylab-${guac_auth_password}.s3-us-west-2.amazonaws.com/lab-key -O /home/ubuntu/lab-key
sed  's|-----BEGIN RSA PRIVATE KEY-----|<param name=\"private-key\">-----BEGIN RSA PRIVATE KEY-----|' -i /home/ubuntu/lab-key
sed  's|-----END RSA PRIVATE KEY-----|-----END RSA PRIVATE KEY-----</param>|' -i /home/ubuntu/lab-key
sed  -e "/@ssh_pki_key@/r /home/ubuntu/lab-key" -i /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml
sed 's|<param name=\"private-key\">@ssh_pki_key@</param>||'  -i /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml
#sed 's/@ssh_pki_key@//' -i /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml
#var internal-ip for u20 console
sed 's/@ssh_console_internal_ip@/${ssh_console_internal_ip}/' -i  /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml

#var internal-ip for w2019 rdp console
sed 's/@win_rdp_internal_ip@/${win_rdp_internal_ip}/' -i  /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml

#var rdp password un is administrator (from randstring gen-pw) also used in userdata ps for w2019
sed 's/@win_rdp_password@/${win_rdp_password}/' -i  /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml

# move user-mapping.xml to correct config location
sudo mv /home/ubuntu/ps-newterra-poc/configs/user-mapping.xml /etc/guacamole/user-mapping.xml

## remember the pki private key for ssh is stored on the s3 bucket...however if this becomes overly complicated, you can create a local un:pw for ssh auth also

################################

sudo cp /home/ubuntu/ps-newterra-poc/

sudo systemctl restart tomcat9 guacd

# Setup Apache Proxy

sudo http_proxy=http://tstark:pssecrocks@172.16.245.222:8888 apt -y install apache2
sudo a2enmod proxy proxy_http headers proxy_wstunnel
sudo systemctl restart apache2

# take from config guacamole.conf and add external ip!
# Have to do this another way...read file from s3 bucket?
#get external ip/dns name
dig +short myip.opendns.com @resolver1.opendns.com > external_ip
cp external_ip /home/ubuntu/external_ip
sed 's/\./-/g' -i external_ip
myextip=`cat external_ip`
sed 's/@public_dns_ip@/'$myextip'/' -i /home/ubuntu/ps-newterra-poc/configs/guacamole.conf

#sed 's/@public_dns@/public_dns/'  -i /home/ubuntu/ps-newterra-poc/config/guacamole.conf
#move the file to the correct location
sudo mv /home/ubuntu/ps-newterra-poc/configs/guacamole.conf /etc/apache2/sites-available/guacamole.conf

# Guacamole /etc/apache2/sites-available/guacamole.conf

sudo a2ensite guacamole.conf

sudo systemctl restart apache2

# one more step to actually publish the site! # now you need to get the certificate running with cert bot mofo
# sudo apt -y install certbot
# sudo apt -y install python3-certbot-apache

# Generated from the terraform!
# sudo certbot --apache --agree-tos --redirect --hsts --staple-ocsp --email you@example.com -d localhost
# Probably should add something about checking /var/log/syslog for "final scriprs compelte"
echo "success2">> ~/peaceinourtime



################################################################################################

