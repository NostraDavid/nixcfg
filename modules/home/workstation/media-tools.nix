{stable, ...}: {
  home.packages = [
    stable.exiftool # Image metadata viewer
    stable.ffmpeg-full # Audio and video processing
    stable.image_optim # Image optimization tool
    stable.imagemagick # ImageMagick CLI
    stable.jpegoptim # JPEG image optimizer
    stable.optipng # PNG image optimizer
    stable.oxipng # Parallel PNG image optimizer
    stable.pngquant # Lossy PNG optimizer
    stable.svgo # SVG optimizer
    stable.yt-dlp # Video and audio downloader
    stable.zopfli # Compression backend for zopflipng
  ];
}
