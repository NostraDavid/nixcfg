#include <brotli/decode.h>
#include <stdint.h>

int main(void) {
  const uint8_t input[] = {0x20, 0x00, 0x10, 0x41, 0x41, 0x41, 0xfc,
                           0xff, 0xff, 0x07, 0x00, 0x22, 0x28, 0xf0,
                           0x0b, 0x60, 0xf7, 0xf4, 0x1f, 0x00, 0x00, 0x00};
  uint8_t output[4096];
  size_t available_in = sizeof(input), available_out = sizeof(output);
  const uint8_t *next_in = input;
  uint8_t *next_out = output;
  BrotliDecoderState *state = BrotliDecoderCreateInstance(NULL, NULL, NULL);
  if (!state)
    return 2;
  BrotliDecoderResult result;
  do {
    available_out = sizeof(output);
    next_out = output;
    result = BrotliDecoderDecompressStream(state, &available_in, &next_in,
                                           &available_out, &next_out, NULL);
  } while (result == BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT);
  int code = BrotliDecoderGetErrorCode(state);
  BrotliDecoderDestroyInstance(state);
  return code == -17 ? 0 : 1;
}
