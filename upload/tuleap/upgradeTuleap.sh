#!/bin/bash

# yum check-update tuleap\*


# Stop service
systemctl stop tuleap
systemctl stop nginx
systemctl stop httpd

# Upgrade packages
yum update -y
# or to upgrade only Tuleap packages (/!\ you might miss security fixes in Tuleap dependencies):
# yum update tuleap\*

# Apply data upgrades
/usr/lib/forgeupgrade/bin/forgeupgrade --config=/etc/tuleap/forgeupgrade/config.ini update

# Re-generate nginx configuration
/usr/share/tuleap/tools/utils/php73/run.php --module=nginx

# Deploy site configurations
tuleap-cfg site-deploy

# Restart service
systemctl start httpd
systemctl start nginx
systemctl start tuleap