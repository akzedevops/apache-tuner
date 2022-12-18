#!/bin/bash

# Set the maximum number of connections allowed
MAX_CONNECTIONS=`ulimit -n`

# Set the maximum amount of memory available
MAX_MEMORY=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)

# Set the maximum number of CPU cores available
MAX_CORES=$(nproc)

# Calculate the optimal values for MaxClients, MaxRequestsPerChild, and MaxSpareServers
MAX_CLIENTS=$((MAX_MEMORY/2048))
MAX_REQUESTS_PER_CHILD=$((MAX_MEMORY*MAX_CORES/1024))
MAX_SPARE_SERVERS=$((MAX_CLIENTS/10))

# Set the values in the Apache configuration file
sed -i "s/MaxClients.*/MaxClients ${MAX_CLIENTS}/" /etc/apache2/httpd.conf
sed -i "s/MaxRequestsPerChild.*/MaxRequestsPerChild ${MAX_REQUESTS_PER_CHILD}/" /etc/apache2/httpd.conf
sed -i "s/MaxSpareServers.*/MaxSpareServers ${MAX_SPARE_SERVERS}/" /etc/apache2/httpd.conf

# Restart Apache to apply the changes
systemctl restart apache2
