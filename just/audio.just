# Switch input to the default audio output monitor.
audio-output:
  @sink="$(pactl get-default-sink)"; \
  source="$sink.monitor"; \
  pactl set-default-source "$source"; \
  for output in $(pactl list source-outputs | awk '/^Source Output #/ {id = substr($3, 2)} /application.name = "Friture"/ {print id}'); do \
    pactl move-source-output "$output" "$source"; \
  done; \
  printf 'Default source: %s\n' "$source"

# Switch input to the Audient iD4 microphone.
audio-mic:
  @source="{{audient_mic_source}}"; \
  pactl set-default-source "$source"; \
  for output in $(pactl list source-outputs | awk '/^Source Output #/ {id = substr($3, 2)} /application.name = "Friture"/ {print id}'); do \
    pactl move-source-output "$output" "$source"; \
  done; \
  printf 'Default source: %s\n' "$source"
