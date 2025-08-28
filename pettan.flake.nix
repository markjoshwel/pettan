# admonition: this is HARD linked to /etc/nixos/flake.nix!
{
  description = "poissonparler server";

  inputs = { nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05"; };

  outputs = inputs@{ self, nixpkgs-stable, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs-stable { inherit system; };
    in {
      nixosConfigurations.pettan = nixpkgs-stable.lib.nixosSystem {
        modules = [
          ./hardware-configuration.nix

          # server-specific config
          {
            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            boot.loader.systemd-boot.enable = true;
            boot.loader.systemd-boot.graceful = true;
            boot.loader.efi.canTouchEfiVariables = true;
            boot.kernelPackages = pkgs.linuxPackages_latest; # latest kernel
            boot.swraid = {
              enable = true;
              mdadmConf = ''
                ARRAY /dev/md0 metadata=1.2 UUID=9fad82ba:ce324086:a8334b2c:f03ca356
              '';
            };

            # user accounts
            users.users.poisson = {
              isNormalUser = true;
              extraGroups = [ "wheel" "docker" ];
              # packages = with pkgs; [ ];
            };

            # List packages installed in system profile.
            # You can use https://search.nixos.org/ to find more packages (and options).
            environment.systemPackages = with pkgs; [
              # essentials
              wget
              htop
              kakoune # for mark

              # we are a server
              docker
              docker-compose
            ];

            # ssh
            services.openssh = {
              enable = true;
              ports = [ 22 ];
              settings = {
                PasswordAuthentication = true;
                AllowUsers = [ "poisson" ];
                PermitRootLogin = "no";
              };
            };

            # tailscale
            services.tailscale = {
              enable = true;
              useRoutingFeatures = "both";
              extraUpFlags = [ "--advertise-exit-node" ];
            };

            # fix suboptimal eno1 configuration for increased udp forwarding 
            # (https://tailscale.com/kb/1320/performance-best-practices#linux-optimizations-for-subnet-routers-and-exit-nodes)
            systemd.services.tailscale-ethtool = {
              description = "tailscale rx-udp-gro-forwarding";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart =
                  "${pkgs.bash}/bin/bash -c 'NETDEV=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 | cut -f5 -d \" \"); ${pkgs.ethtool}/bin/ethtool -K \"$NETDEV\" rx-udp-gro-forwarding on rx-gro-list off'";
              };
              wantedBy = [ "multi-user.target" ];
            };

            # Some programs need SUID wrappers, can be configured further or are
            # started in user sessions.
            # programs.mtr.enable = true;
            # programs.gnupg.agent = {
            #   enable = true;
            #   enableSSHSupport = true;
            # };

            # docker
            virtualisation.docker.enable = true;
            virtualisation.docker = {
              rootless = {
                enable = true;
                setSocketVariable = true;
                daemon.settings.log-driver = "journald";
              };
            };
            security.wrappers = {
              docker-rootlesskit = {
                owner = "root";
                group = "root";
                capabilities = "cap_net_bind_service+ep";
                source = "${pkgs.rootlesskit}/bin/rootlesskit";
              };
            };

            # networking (wan, not lan)
            # 0-1023 unavail because we're using rootless docker
            networking.firewall.enable = true;
            networking.firewall.allowedTCPPorts = [
              # 80, 443    - caddy redirected from docker
              # 7080, 7443 - caddy in docker original port
              80
              443
              7080
              7443
              25565 # minenhandwerkerwelt
              # 22 # ssh
              # 9443 # portainer
            ];
            networking.firewall.allowedUDPPorts = [
              # quic/http3 (docker redirect, original port)
              443
              7443
              6881 # m1 please bro i torrent linux isos oni bro
              # 19132  # minenhandwerkerwelt bedrock
              # 1900   # ssdp/upnp
              # 7359   # jellyfin dlna (m1 please bro its my school videos bro)
            ];
            networking.firewall.extraCommands = ''
              iptables -A PREROUTING -t nat -i eth0 -p TCP --dport 80 -j REDIRECT --to-port 7080
              iptables -A PREROUTING -t nat -i eth0 -p TCP --dport 443 -j REDIRECT --to-port 7443
              iptables -A PREROUTING -t nat -i eth0 -p UDP --dport 443 -j REDIRECT --to-port 7443
              iptables -A PREROUTING -t nat -i eth0 -p TCP --dport 53 -j REDIRECT --to-port 7053
              iptables -A PREROUTING -t nat -i eth0 -p UDP --dport 53 -j REDIRECT --to-port 7053
            '';
            boot.kernel.sysctl = {
              "net.ipv4.conf.eth0.forwarding" = 1; # enable
            };

            # no wireless networking; this is a server
            networking.hostName = "pettan";
            time.timeZone = "Asia/Singapore";

            system.stateVersion =
              "25.05"; # dangerous, https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
          }
        ];
      };
    };
}
