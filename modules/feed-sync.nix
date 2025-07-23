{config, ...}: let
  # change this once and every host picks it up
  feedsRepo = "${config.home.homeDirectory}/repos/tb-feeds";
in {
  ### systemd user service ###
  systemd.user.services.feeds-sync = {
    Unit = {
      Description = "Commit Thunderbird RSS feeds to git and push";
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "GIT_DIR=${feedsRepo}/.git"
        "GIT_WORK_TREE=${feedsRepo}"
      ];
      ExecStart = ''
        set -eu
        cd "${feedsRepo}/Feeds"

        git add feeds.json feeditems.json

        # if ! git diff --cached --quiet; then
          # git commit -m "feeds: $(date --iso-8601=seconds)"
          # ignore failure when offline
          # git push --quiet || true
        fi
      '';
    };
  };

  ### systemd user timer ###
  systemd.user.timers.feeds-sync = {
    Unit.Description = "Run feed-git sync regularly";
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      Persistent = true;
    };
    Install.WantedBy = ["default.target"];
  };
}
