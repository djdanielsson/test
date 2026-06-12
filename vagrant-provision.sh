#!/bin/bash

set -e

echo "🚀 Starting Chef provisioning in Vagrant VM..."

# Update system
apt-get update

# Install build tools for gem compilation
apt-get install -y build-essential

# Install Chef if not present
if ! command -v chef-solo &> /dev/null; then
    echo "📦 Installing Chef..."
    curl -L https://omnitruck.chef.io/install.sh | bash
fi

# Create chef cache directory
mkdir -p /var/chef-solo

# Change to cookbook directory
cd /chef-repo

# Install Berkshelf if not present
if ! command -v berks &> /dev/null && ! [ -f "/opt/chef/embedded/bin/berks" ]; then
    echo "📦 Installing Berkshelf..."
    /opt/chef/embedded/bin/gem install berkshelf
fi

# Download cookbook dependencies using Berkshelf
echo "📚 Downloading cookbook dependencies..."
/opt/chef/embedded/bin/berks install
/opt/chef/embedded/bin/berks vendor cookbooks

# Accept Chef license and set up
export CHEF_LICENSE=accept-silent

# Accept Chef license and run Chef
echo "👨‍🍳 Running Chef Solo..."
/opt/chef/bin/chef-solo -c solo.rb -j solo.json

echo "✅ Chef provisioning complete!"
echo ""
echo "🔗 Your sites are available at:"
echo "   • http://192.168.56.10 or https://192.168.56.10"
echo "   • https://test.cluster.local:8443"
echo "   • https://ci.cluster.local:8443"
echo "   • https://status.cluster.local:8443"
echo ""
echo "🖥️  From host machine:"
echo "   • http://localhost:8080"
echo "   • https://localhost:8443"
echo ""
echo "⚠️  Note: You may see SSL warnings since we're using self-signed certificates"
