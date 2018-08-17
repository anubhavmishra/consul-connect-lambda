#!/bin/bash

export IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

apt-get update
# Install packages
apt-get install -y unzip dnsmasq nginx vim

# Create UNIX user
sudo adduser --disabled-password --disabled-login --no-create-home consul

## Setup consul
mkdir -p /var/lib/consul
mkdir -p /etc/consul.d

# Set permissions
chown -R consul:consul /var/lib/consul

curl \
  --silent \
  --location \
  --output consul.zip \
  https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip

#curl -s --location --output consul.zip https://raw.githubusercontent.com/anubhavmishra/consul-connect-lambda/master/consul.zip
unzip consul.zip
mv consul /usr/local/bin/consul
rm consul.zip

cat > consul.service <<'EOF'
[Unit]
Description=consul
Documentation=https://consul.io/docs/

[Service]
User=consul
Group=consul

ExecStart=/usr/local/bin/consul agent \
  -advertise=ADVERTISE_ADDR \
  -datacenter=${datacenter} \
  -bind=0.0.0.0 \
  -retry-join "provider=aws tag_key=${retry_join_tag} tag_value=${retry_join_tag}" \
  -data-dir=/var/lib/consul \
  -config-dir=/etc/consul.d \
  -enable-script-checks

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sed -i "s/ADVERTISE_ADDR/$IP_ADDRESS/" consul.service
mv consul.service /etc/systemd/system/consul.service
systemctl enable consul

# Register web service
sudo tee /etc/consul.d/web.json > /dev/null <<"EOF"
{
  "service": {
    "name": "web",
    "port": 80,
    "checks": [{
        "http": "http://localhost/",
        "interval": "5s"
    }],
    "connect": { "proxy": {} }
  }
}
EOF

# Set permissions for Consul configuration
chown -R consul:consul /etc/consul.d

# Configure dnsmasq
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/10-consul <<'EOF'
server=/consul/127.0.0.1#8600
EOF

systemctl enable dnsmasq
systemctl start dnsmasq
# Force restart for adding consul dns
systemctl restart dnsmasq

# Rewrite Nginx default webpage
mkdir -p /var/www/html
sudo tee /var/www/html/index.nginx-debian.html > /dev/null <<"EOF"
<!DOCTYPE html>
<html>
<head>
    <title>Consul Connect Lambda</title>
    <style>
        body {
            width: 38em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
</head>
<body>
    <img src="https://github.com/anubhavmishra/consul-connect-lambda/raw/master/images/consul-connect.gif" title="Consul Connect" />
    <h1>Consul Connect-Native Integration</h1>
    <p>Hostname: ${hostname}</p>
    <p>
        <a title="Read more" href="https://www.consul.io/docs/connect/native.html">Read more >></a>
    </p>
</body>
</html>

EOF

echo "Setting hostname....."
sudo tee /etc/hostname > /dev/null <<"EOF"
${hostname}
EOF
sudo hostname -F /etc/hostname
sudo tee -a /etc/hosts > /dev/null <<EOF
# For local resolution
$IP_ADDRESS  ${hostname}
EOF

systemctl restart nginx
systemctl start consul