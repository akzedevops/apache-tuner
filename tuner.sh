#!/bin/bash
set -euo pipefail

APACHE_CONF="/etc/apache2/httpd.conf"
APACHE_LOG="/var/log/apache2/access.log"

# Set the maximum number of connections allowed
MAX_CONNECTIONS=$(ulimit -n)

# Set the maximum amount of memory available (in MB)
MAX_MEMORY=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)

# Set the maximum number of CPU cores available
MAX_CORES=$(nproc)

# Analyze logs for concurrent connections if available
CONCURRENT_PEAK=0
if [[ -f "$APACHE_LOG" ]] || compgen -G "${APACHE_LOG}*" > /dev/null; then
    CONCURRENT_PEAK=$(zcat -f "${APACHE_LOG}"* 2>/dev/null | \
        awk '{print $4}' | cut -d: -f1-3 | uniq -c | \
        sort -rn | head -1 | awk '{print $1}')
    CONCURRENT_PEAK=${CONCURRENT_PEAK:-0}
fi

# Calculate the optimal values for MaxClients, MaxRequestsPerChild, and MaxSpareServers
MAX_CLIENTS=$((MAX_MEMORY / 2048))
[[ $CONCURRENT_PEAK -gt 0 ]] && MAX_CLIENTS=$(( CONCURRENT_PEAK * 3 / 2 ))
[[ $MAX_CLIENTS -gt $MAX_CONNECTIONS ]] && MAX_CLIENTS=$MAX_CONNECTIONS
MAX_REQUESTS_PER_CHILD=$((MAX_MEMORY * MAX_CORES / 1024))
MAX_SPARE_SERVERS=$((MAX_CLIENTS / 10))

# Verify configuration file exists
if [[ ! -f "$APACHE_CONF" ]]; then
    echo "Error: Apache configuration file not found at $APACHE_CONF" >&2
    exit 1
fi

# Set the values in the Apache configuration file
sed -i "s/^[[:space:]]*MaxClients.*/MaxClients ${MAX_CLIENTS}/" "$APACHE_CONF"
sed -i "s/^[[:space:]]*MaxRequestsPerChild.*/MaxRequestsPerChild ${MAX_REQUESTS_PER_CHILD}/" "$APACHE_CONF"
sed -i "s/^[[:space:]]*MaxSpareServers.*/MaxSpareServers ${MAX_SPARE_SERVERS}/" "$APACHE_CONF"

# Restart Apache to apply the changes
if systemctl restart apache2; then
    echo "Apache tuned successfully (Peak concurrent: ${CONCURRENT_PEAK}): MaxClients=${MAX_CLIENTS}, MaxRequestsPerChild=${MAX_REQUESTS_PER_CHILD}, MaxSpareServers=${MAX_SPARE_SERVERS}"
else
    echo "Error: Failed to restart Apache" >&2
    exit 1
fi
