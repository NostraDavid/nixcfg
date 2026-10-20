{
  local,
  stable,
  ...
}: {
  home.packages = [
    stable.freetype # Font-rendering runtime for WhatPulse
    stable.libpcap # Packet-capture runtime for WhatPulse
    local.whatpulse # Personal activity and productivity analytics
  ];
}
