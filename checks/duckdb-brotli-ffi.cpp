#include <brotli/decode.h>

// Expose the vendored C++ decoder to the same tests as the shared C library.
extern "C" {
void *BrotliDecoderCreateInstance(void *, void *, void *) {
  return duckdb_brotli::BrotliDecoderCreateInstance(nullptr, nullptr, nullptr);
}

void BrotliDecoderDestroyInstance(void *state) {
  duckdb_brotli::BrotliDecoderDestroyInstance(
      static_cast<duckdb_brotli::BrotliDecoderState *>(state));
}

int BrotliDecoderGetErrorCode(void *state) {
  return duckdb_brotli::BrotliDecoderGetErrorCode(
      static_cast<duckdb_brotli::BrotliDecoderState *>(state));
}

const char *BrotliDecoderErrorString(int code) {
  return duckdb_brotli::BrotliDecoderErrorString(
      static_cast<duckdb_brotli::BrotliDecoderErrorCode>(code));
}

int BrotliDecoderDecompressStream(void *state, size_t *available_in,
                                const uint8_t **next_in, size_t *available_out,
                                uint8_t **next_out, size_t *total_out) {
  return duckdb_brotli::BrotliDecoderDecompressStream(
      static_cast<duckdb_brotli::BrotliDecoderState *>(state), available_in,
      next_in, available_out, next_out, total_out);
}
}
