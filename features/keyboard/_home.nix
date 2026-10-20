# Home Manager keyboard configuration.
_: {
  xdg.configFile."kxkbrc".text = ''
    [Layout]
    Use=true
    LayoutList=us,runic
    Layout=us
    VariantList=,basic
    Options=caps:f13,lv3:ralt_switch_multikey,compose:ralt,compose:rctrl,mod_led:compose,grp:win_space_toggle
  '';
}
