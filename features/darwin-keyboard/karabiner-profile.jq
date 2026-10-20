# shortcut: input must be JSON; add JSONC parsing if hand-edited configs need it.
if length != 1 then
  error("Expected exactly one Karabiner configuration object")
else
  .[0]
  | if type != "object" or (has("profiles") and (.profiles | type) != "array") then
      error("Expected a Karabiner configuration object with a profiles array")
    else
      .profiles = ([$profile[0]] + [
        (.profiles // [])[]
        | select(.name != $profile[0].name)
        | .selected = false
      ])
    end
end
