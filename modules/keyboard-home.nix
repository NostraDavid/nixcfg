{...}: {
  xdg.configFile."kxkbrc".text = ''
    [Layout]
    Use=true
    LayoutList=us,runic
    Layout=us
    VariantList=,basic
    Options=caps:escape_shifted_compose,lv3:ralt_switch_multikey,compose:ralt,compose:rctrl,mod_led:compose,grp:win_space_toggle
  '';
}
