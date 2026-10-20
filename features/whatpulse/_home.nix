{
  local,
  stable,
  ...
}: {
  home.packages = [
    local.whatpulse # Personal activity and productivity analytics
    stable.freetype # Font-rendering runtime for WhatPulse
    stable.libpcap # Packet-capture runtime for WhatPulse
  ];
}
