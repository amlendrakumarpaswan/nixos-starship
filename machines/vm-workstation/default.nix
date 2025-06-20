{ lib, config, pkgs, ... }:
{

  networking = {

    networkmanager.enable = true;

    hostName = "server-workstation";

    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.100.51";
        prefixLength = 24;
      }];
    };
    defaultGateway = {
      address = "192.168.100.1";
      interface = "ens18";
    };
    nameservers = ["1.1.1.1"];
  
  }; # end networking block

  environment.systemPackages = with pkgs; [
    syncthing
    kubectl
    helm
    remmina
  ];

  users.users = lib.mkForce {
    library = {
      isNormalUser = true;
      description = "library";
      extraGroups = [ "networkmanager" "wheel" "plugdev" "dialout" "seclogs" ];
      packages = with pkgs; [];
    };
  };

}
