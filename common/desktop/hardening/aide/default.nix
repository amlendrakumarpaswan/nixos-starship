{ config, lib, pkgs, ... }:
{

  environment = {
    systemPackages = with pkgs; [
      aide
    ];

    etc = {
      "aide.conf".source = ./aide.conf;

      # Add scripts to /etc/scripts/

      #################################
      # Initialize AIDE database script
      "scripts/aide-init.sh".text = ''
        #!/usr/bin/env bash
        LOGFILE="/var/log/aide/aide-init.log"

        echo "Checking for AIDE database..." | tee -a "$LOGFILE"
        if [ ! -f /var/lib/aide/aide.db.gz ]; then
            echo "AIDE database not found. Initializing..." | tee -a "$LOGFILE"
            mkdir -p /var/lib/aide && \
            ${pkgs.aide}/bin/aide --init >> "$LOGFILE" 2>&1 && \
            if [ -f /var/lib/aide/aide.db.new.gz ]; then
                mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
                echo "AIDE database created successfully." | tee -a "$LOGFILE"
            else
                echo "Error: AIDE failed to generate the database file." >&2 | tee -a "$LOGFILE"
                exit 1
            fi
        else
            echo "AIDE database already exists. Skipping initialization." | tee -a "$LOGFILE"
        fi
      '';

      ############################
      # Periodic AIDE check script
      "scripts/aide-check.sh".text = ''
        #!/usr/bin/env bash
        echo "Starting AIDE filesystem integrity check..."
        ${pkgs.aide}/bin/aide --check >> /var/log/aide/aide-check.log 2>&1;
        echo "AIDE check completed. Results logged to /var/log/aide/aide-check.log."
        '';

      ###################################################
      # Script to check AIDE logs, for notifying / alerts
      "scripts/check-aide-errors.sh".text = ''

        #!/usr/bin/env bash

        LOGFILE="/var/log/aide/aide-check.log"
        STATE_FILE="/var/tmp/aide-last-checked.log"

        # Icon definitions
        ICON_ALERT=""
        ICON_NORMAL=""

        [[ ! -f "$STATE_FILE" ]] && touch "$STATE_FILE"

        new_errors=$(grep -E "(Added file|Changed file|Removed file)" "$LOGFILE" | grep -v -F -f "$STATE_FILE")

        if [[ -n "$new_errors" ]]; then
          # Alert state: Icon (red) + text
          grep -E "(Added file|Changed file|Removed file)" "$LOGFILE" > "$STATE_FILE"
          printf '{"text": "AIDE %s", "tooltip": "%s", "class": "alert"}\n' \
            "$ICON_ALERT" "$(echo "$new_errors" | sed 's/"/\\"/g')"
        else
          # Normal state: Icon (green) + text
          printf '{"text": "AIDE %s", "tooltip": "No AIDE issues detected", "class": "normal"}\n' \
            "$ICON_NORMAL"
        fi

      '';

      ######################
      # Make 'em executable!
      "scripts/aide-init.sh".mode = "0755";
      "scripts/aide-check.sh".mode = "0755";
      "scripts/check-aide-errors.sh".mode = "0755";

    }; # end etc block

  }; # end environment block

  systemd = {
    # Make sure files exist with correct permissions:
    tmpfiles.rules = [
      "d /var/log/aide 0750 root root -" # Ensure /var/log/aide/ exists with correct permissions
      "f /var/log/aide/aide.log 0640 root root -" # Ensure the aide.log file exists and is writable
      "d /var/t极 0777 root root -"
      "f /var/log/aide/aide-check.log 0640 root seclogs -"
    ];

    services = {
      # Initialize AIDE database (only runs if no database exists)
      aideInit = {
        description = "Initialize AIDE database if it doesn't exist";
        wantedBy = [ "multi-user.target" ];
        unitConfig = {
          ConditionPathExists = "!/var/lib/aide/aide.db.gz"; # Run only if the file is missing
        };
        serviceConfig = {
          Type = "oneshot"; # Run once and stop
          ExecStart = "${pkgs.bash}/bin/bash /etc/scripts/aide-init.sh";
        };
      };

      # Perform AIDE integrity checks
      aideCheck = {
        description = "Run AIDE filesystem integrity check";
        wantedBy = [ "timers.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash /etc/scripts/aide-check.sh";
        };
      };
    };

    # SYSTEMD TIMER: Schedule periodic AIDE integrity checks
    timers.aideCheck = {
      enable = true;
      description = "Daily AIDE filesystem integrity checks";
      timerConfig = {
        OnCalendar = "daily"; # Runs daily at midnight (adjust as needed)
        Persistent = true;    # Recovers missed checks after system downtime
      };
      wantedBy = [ "timers.target" ];

    }; # end services block

  }; # end systemd block

}
