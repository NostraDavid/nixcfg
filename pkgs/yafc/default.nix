{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  gettext,
  libbsd,
  readline,
  libssh,
  openssl,
}:
stdenv.mkDerivation rec {
  pname = "yafc";
  version = "1.3.7";

  src = fetchurl {
    url = "https://deb.debian.org/debian/pool/main/y/yafc/yafc_${version}.orig.tar.xz";
    hash = "sha256-Sz6/YkI/Ib2qJEm2bRXo0LsEIVRyy2OjHUc8PDkSweA=";
  };

  nativeBuildInputs = [
    pkg-config
    gettext
  ];

  buildInputs = [
    libbsd
    readline
    libssh
    openssl
  ];

  configureFlags = [
    "--with-readline"
    "--with-ssh"
    "--with-bash-completion=${placeholder "out"}/share/bash-completion/completions"
  ];

  postPatch = ''
    substituteInPlace src/syshdr.h \
      --replace-fail 'extern char *readline ();' '#    error "readline without headers!"' \
      --replace-fail 'extern void add_history ();' '#    error "readline without headers!"' \
      --replace-fail 'extern int write_history ();' "" \
      --replace-fail 'extern int read_history ();' "" \
      --replace-fail '#if defined(HAVE_LIBEDIT) || (defined(HAVE_LIBREADLINE) && RL_READLINE_VERSION < 0x0602)' '#if defined(HAVE_LIBEDIT)'
  '';

  meta = with lib; {
    description = "Command-line FTP client with readline, bookmarks, and SFTP support";
    homepage = "https://github.com/sebastinas/yafc";
    license = licenses.gpl2Only;
    mainProgram = "yafc";
    platforms = platforms.unix;
  };
}
