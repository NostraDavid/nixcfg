{...}: {
  environment.etc."xdg/kxkbrc".text = ''
    [Layout]
    LayoutList=us
    Layout=us
    Options=caps:escape_shifted_compose,lv3:ralt_switch_multikey,compose:ralt,compose:rctrl,mod_led:compose
  '';
}
