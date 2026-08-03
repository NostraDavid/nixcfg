{pkgs, ...}: let
  stable = pkgs;
  local = {inherit (pkgs) whatpulse;};
in {
  home.packages = [
    stable.freetype # Font-rendering runtime for WhatPulse
    stable.libpcap # Packet-capture runtime for WhatPulse
    local.whatpulse # Personal activity and productivity analytics
  ];
}
