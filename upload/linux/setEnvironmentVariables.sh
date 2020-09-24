#!/bin/bash

# Abort on any error
set -e

# set environment variables

echo "export proxy=$proxy" >> /root/.bashrc
echo "export hostname=$hostname" >> /root/.bashrc
echo "export domainname=$domainname" >> /root/.bashrc


echo 'LINUX INSTALLER: Environment Variables Set'