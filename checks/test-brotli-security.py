"""Check the actual decoder boundary for CVE-2026-111497."""

import ctypes
import os
import subprocess
import unittest

# Node's upstream regression vector, not an executable payload.
INVALID_SWITCH = bytes.fromhex("200010414141fcffff07002228f00b60f7f41f000000")
BYTE = ctypes.c_uint8
POINTER = ctypes.POINTER(BYTE)
SIZE = ctypes.c_size_t


def decoder(path: str) -> ctypes.CDLL:
    library = ctypes.CDLL(path)
    library.BrotliDecoderCreateInstance.argtypes = [ctypes.c_void_p] * 3
    library.BrotliDecoderCreateInstance.restype = ctypes.c_void_p
    library.BrotliDecoderDestroyInstance.argtypes = [ctypes.c_void_p]
    library.BrotliDecoderGetErrorCode.argtypes = [ctypes.c_void_p]
    library.BrotliDecoderGetErrorCode.restype = ctypes.c_int
    library.BrotliDecoderErrorString.argtypes = [ctypes.c_int]
    library.BrotliDecoderErrorString.restype = ctypes.c_char_p
    library.BrotliDecoderDecompressStream.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(SIZE),
        ctypes.POINTER(POINTER),
        ctypes.POINTER(SIZE),
        ctypes.POINTER(POINTER),
        ctypes.POINTER(SIZE),
    ]
    library.BrotliDecoderDecompressStream.restype = ctypes.c_int
    return library


def decompress(library: ctypes.CDLL, data: bytes, chunk_size: int) -> tuple[bytes, int]:
    state = library.BrotliDecoderCreateInstance(None, None, None)
    if not state:
        raise MemoryError("Could not allocate the Brotli decoder")
    output = bytearray()
    try:
        for offset in range(0, len(data), chunk_size):
            chunk = data[offset : offset + chunk_size]
            source = (BYTE * len(chunk)).from_buffer_copy(chunk)
            source_pointer = ctypes.cast(source, POINTER)
            source_size = SIZE(len(chunk))
            while True:
                target = (BYTE * 4096)()
                target_pointer = ctypes.cast(target, POINTER)
                target_size = SIZE(len(target))
                total = SIZE()
                status = library.BrotliDecoderDecompressStream(
                    state,
                    ctypes.byref(source_size),
                    ctypes.byref(source_pointer),
                    ctypes.byref(target_size),
                    ctypes.byref(target_pointer),
                    ctypes.byref(total),
                )
                output.extend(bytes(target)[: len(target) - target_size.value])
                if status != 3:  # BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
                    break
            if status != 2:  # BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT
                break
        return bytes(output), library.BrotliDecoderGetErrorCode(state)
    finally:
        library.BrotliDecoderDestroyInstance(state)


class BrotliSecurityTests(unittest.TestCase):
    def test_shared_decoder(self) -> None:
        library = decoder(os.environ["BROTLI_LIBRARY"])
        self.assertEqual(
            library.BrotliDecoderErrorString(-17), b"_ERROR_FORMAT_BLOCK_SWITCH"
        )
        for chunk_size in (1, len(INVALID_SWITCH)):
            with self.subTest(chunk_size=chunk_size):
                _, code = decompress(library, INVALID_SWITCH, chunk_size)
                self.assertEqual(code, -17)

    def test_valid_streams(self) -> None:
        library = decoder(os.environ["BROTLI_LIBRARY"])
        for original in (b"", b"ordinary text\n" * 10000, bytes(range(256))):
            compressed = subprocess.run(  # noqa: S603 - Nix supplies the trusted CLI.
                [os.environ["BROTLI_CLI"], "-c"],
                input=original,
                capture_output=True,
                check=True,
            ).stdout
            for chunk_size in (1, max(1, len(compressed))):
                with self.subTest(size=len(original), chunk_size=chunk_size):
                    actual, code = decompress(library, compressed, chunk_size)
                    self.assertEqual(code, 1)
                    self.assertEqual(actual, original)

    def test_invalid_header(self) -> None:
        library = decoder(os.environ["BROTLI_LIBRARY"])
        for chunk_size in (1, 16):
            with self.subTest(chunk_size=chunk_size):
                _, code = decompress(library, b"\xff" * 16, chunk_size)
                self.assertLess(code, 0)


if __name__ == "__main__":
    unittest.main()
