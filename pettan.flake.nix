# admonition: this is HARD linked to /etc/nixos/flake.nix!
{
  description = "poissonparler server";

  inputs = { nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11"; };

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
              
              # fs tools
              smartmontools     # disk health (smartctl)
              lsof              # list open files
              
              # net tools
              tcpdump           # packet capture
              mtr               # network diagnostic
              nmap              # network scanning
              
              # sys tools
              sysstat           # iostat, mpstat, sar
              iotop-c           # io monitoring
              iftop             # network bandwidth
              btop              # modern htop alternative
              ncdu              # disk usage analyzer
              tmux              # terminal multiplexer
              tree              # directory tree viewer
              ripgrep           # fast grep
              fd                # fast find
              duf               # modern df alternative
              ctop              # container monitoring
              dive              # docker image analysis
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
            virtualisation.docker.daemon.settings = {
              log-driver = "journald";
              data-root = "/mnt/md0/docker";
            };

            systemd.services.start-pettan-docker = {
              description = "start pettan docker";
              wants = [ "docker.service" ];
              after = [ "docker.service" ];
              serviceConfig = {
                Type = "simple";
                WorkingDirectory = "/mnt/md0";
                ExecStart = "${pkgs.docker-compose}/bin/docker-compose up";
                Restart = "always";
                User = "poisson";
                Group = "docker";
              };
              wantedBy = [ "multi-user.target" ];
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
