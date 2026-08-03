{
  local,
  stable,
  ...
}: {
  home.packages = [
    local.jpegli # JPEG encoder and decoder for image processing and compression
    stable.exiftool # Inspect and edit media metadata
    stable.ffmpeg-full # Audio and video conversion toolkit
    stable.gifsicle # Optimize and manipulate GIF images
    stable.graphicsmagick # Image processing toolkit
    stable.image_optim # Image optimization frontend
    stable.imagemagick # Image processing toolkit
    stable.jpeginfo # Validate JPEG images
    stable.jpegoptim # Optimize JPEG images
    stable.libavif # AVIF image tools
    stable.libjpeg_turbo # JPEG tools, including jpegtran
    stable.libjxl # JPEG XL tools
    stable.librsvg # SVG rendering tools
    stable.libtiff # TIFF image tools
    stable.libwebp # WebP image tools
    stable.optipng # Optimize PNG images
    stable.oxipng # Multithreaded PNG optimizer
    stable.pngcheck # Validate PNG images
    stable.pngquant # Lossy PNG compressor
    stable.poppler-utils # PDF inspection and conversion tools
    stable.svgo # SVG optimizer
    stable.yt-dlp # Download video and audio streams
    stable.zopfli # High-ratio compression and zopflipng
  ];
}
