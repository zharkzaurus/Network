#!/bin/bash

# Update package lists
sudo apt-get update

# Install BIND9
sudo apt-get install -y bind9 bind9utils bind9-doc

# Configure BIND9 options
sudo cp /etc/bind/named.conf.options /etc/bind/named.conf.options.bak
sudo cat > /etc/bind/named.conf.options << EOF
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    forwarders {
        8.8.8.8;  // Google's Public DNS
        8.8.4.4;  // Google's Public DNS
    };
    dnssec-validation auto;
    auth-nxdomain no;    # conform to RFC1035
    listen-on { any; };
    listen-on-v6 { any; };
};
EOF

# Create zone files directory
sudo mkdir -p /etc/bind/zones

# Set permissions for zone files directory
sudo chown -R bind:bind /etc/bind/zones

# Create the forward zone file
sudo cat > /etc/bind/zones/db.zharkzaurus.com << EOF
\$TTL 86400
@   IN  SOA ns1.zharkzaurus.com. admin.zharkzaurus.com. (
        2024060801
        3600
        1800
        604800
        86400
)
@   IN  NS  ns1.zharkzaurus.com.
ns1 IN  A   192.168.68.158
www IN  A   192.168.68.158
EOF

# Create the reverse zone file
sudo cat > /etc/bind/zones/db.68.168.192 << EOF
\$TTL 86400
@   IN  SOA ns1.zharkzaurus.com. admin.zharkzaurus.com. (
        2024060801
        3600
        1800
        604800
        86400
)
@   IN  NS  ns1.zharkzaurus.com.
158 IN  PTR ns1.zharkzaurus.com.
EOF

# Include zone files in named.conf.local
sudo cat > /etc/bind/named.conf.local << EOF
zone "zharkzaurus.com" {
    type master;
    file "/etc/bind/zones/db.zharkzaurus.com";
};
zone "68.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.68.168.192";
};
EOF

# Configure BIND logging
sudo tee /etc/bind/named.conf.logging >/dev/null <<EOF
logging {
    channel default_log {
        file "/var/log/named/default.log" versions 3 size 10m;
        severity info;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    channel query_log {
        file "/var/log/named/query.log" versions 3 size 10m;
        severity debug 3;
        print-time yes;
        print-severity yes;
        print-category yes;
    };
    category default { default_log; };
    category queries { query_log; };
    category security { default_log; };
};
EOF

# Include logging configuration in named.conf
sudo cat >> /etc/bind/named.conf << EOF
include "/etc/bind/named.conf.logging";
EOF

# Create log directory and set permissions
sudo mkdir -p /var/log/named
sudo touch /var/log/named/default.log /var/log/named/query.log
sudo chown -R bind:bind /var/log/named

# Configure AppArmor for BIND
sudo tee -a /etc/apparmor.d/local/usr.sbin.named >/dev/null <<EOF
/var/log/named/** rw,
/var/log/named/ rw,
EOF

# Reload AppArmor profiles
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.named

# Restart BIND9 service
sudo systemctl restart bind9

echo "BIND9 setup complete."
