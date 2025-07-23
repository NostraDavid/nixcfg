{...}: {
  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocales = [
      "nl_NL.UTF-8/UTF-8"
      "en_DK.UTF-8/UTF-8"
      "en_US/ISO-8859-1"
    ];
    extraLocaleSettings = {
      # https://www.man7.org/linux/man-pages/man7/locale.7.html
      # LC_ALL = "en_US.UTF-8";

      # Address format (street, city, postal code)
      LC_ADDRESS = "nl_NL.UTF-8";
      # Alphabetical sorting order
      LC_COLLATE = "en_US.UTF-8";
      # Character classification (letters, numbers, etc.)
      LC_CTYPE = "en_US.UTF-8";
      # Metadata about the locale
      LC_IDENTIFICATION = "nl_NL.UTF-8";
      # Currency format (€, comma for decimal)
      LC_MONETARY = "nl_NL.UTF-8";
      # System and application language
      LC_MESSAGES = "en_US.UTF-8";
      # Measurement units (metric system)
      LC_MEASUREMENT = "nl_NL.UTF-8";
      # Name formatting conventions
      LC_NAME = "nl_NL.UTF-8";
      # Number format (comma for decimal)
      LC_NUMERIC = "en_US.UTF-8";
      # Default paper size (A4)
      LC_PAPER = "nl_NL.UTF-8";
      # Telephone number format
      LC_TELEPHONE = "nl_NL.UTF-8";
      # Date and time format (YYYY-MM-DD)
      LC_TIME = "en_DK.UTF-8";

      LANGUAGE = "en_US.UTF-8";
    };
  };
}
