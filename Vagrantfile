Vagrant.configure("2") do |config|
  config.vm.box = "generic/fedora42"
  config.vm.hostname = "chef-nginx"
  
  # Network configuration
  config.vm.network "private_network", ip: "192.168.121.10"
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 443, host: 8443
  
  # VM resources for libvirt
  config.vm.provider "libvirt" do |lv|
    lv.memory = 2048
    lv.cpus = 2
    lv.title = "chef-nginx-multisite"
  end
  
  # Sync cookbook to VM using rsync
  config.vm.synced_folder ".", "/chef-repo", type: "rsync", rsync__exclude: ".git/"
  
  # # Add entries to /etc/hosts for testing
  # config.vm.provision "shell", inline: <<-SHELL
  #   echo "192.168.121.10 test.cluster.local" >> /etc/hosts
  #   echo "192.168.121.10 ci.cluster.local" >> /etc/hosts
  #   echo "192.168.121.10 status.cluster.local" >> /etc/hosts
  # SHELL
  
  # Install and run Chef

  config.vm.provision "shell", path: "./vagrant-provision.sh"
  
  # Optional: Use Chef provisioner instead
  # config.vm.provision "chef_solo" do |chef|
  #   chef.cookbooks_path = "."
  #   chef.add_recipe "nginx-multisite"
  #   chef.json = JSON.parse(File.read("solo.json"))
  # end
end
