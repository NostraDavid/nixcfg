// Intl supplies the local date and DST offset; RFC 3339 needs different separators.
(() => {
  const clock = document.querySelector(".information-widget-datetime span");
  if (!clock) return;

  const format = () => {
    const node = clock.firstChild;
    if (!node || node.nodeType !== Node.TEXT_NODE) return;
    const value = node.nodeValue.replace(
      /^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+GMT([+-]\d{2}:\d{2})$/,
      "$1T$2$3",
    );
    if (node.nodeValue !== value) node.nodeValue = value;
  };

  new MutationObserver(format).observe(clock, {
    childList: true,
    characterData: true,
    subtree: true,
  });
  format();
})();
