# Chrome and Firefox add-ons on Wodan

Google Chrome is enabled only for Wodan. Firefox, Chromium and the default
browser are unchanged. The Firefox inventory on 2026-11-03 contained 53 active
user extensions and two disabled user extensions; Firefox's built-in extensions
are excluded.

## Installation and activation

Chrome 156.0.8078.79 was installed into David's Nix user profile so the browser
is available immediately as `google-chrome`. Home Manager also declares Chrome
for future system generations.

The 40 Chrome extensions below are configured for automatic installation from
the Chrome Web Store. Their downloaded store packages were checked for Manifest
V3 compatibility. This verifies availability and manifest version, not every
extension's runtime behavior.

The extension policy still needs system activation: the agent environment cannot
use `sudo`. Run `just switch wodan` from this checkout, then restart Chrome.
Check `chrome://policy` for `ExtensionSettings` and `SiteSearchSettings`, and
`chrome://extensions` for installation status. Allow time for store downloads.
The switch applies the entire current checkout, including unrelated changes;
review those first.

The policy at `/etc/opt/chrome/policies/managed/firefox-addons.json` links to
`dotfiles/google-chrome/etc/opt/chrome/policies/managed/firefox-addons.json` in
the live checkout. It is not rendered or copied into the store. Subsequent edits
need a policy reload or browser restart, not another system switch.
`normal_installed` allows the user to disable an extension; this is not a
force-install policy. It applies to Chrome profiles on Wodan, not Firefox or
Chromium. Chrome may show “Managed by your organization” because of this local
policy; no cloud enrollment is configured.

After the first successful switch, the duplicate user-profile package can be
removed with `nix profile remove google-chrome`; Home Manager then supplies it.
Do not remove it before activation.

## Chrome extensions

Links identify the exact store entries used by the policy. “Same” means the
corresponding Chrome product, not identical behavior or migrated settings.

| Firefox extension                                     | Chrome extension                                                                                                  | Mapping                                                                              |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Unpaywall                                             | [Unpaywall](https://chromewebstore.google.com/detail/iplffkdpngmdjhlpjmppncnlhomiipha)                            | Same                                                                                 |
| FireShot                                              | [FireShot](https://chromewebstore.google.com/detail/mcbpblocgmgfnpjjppndjkmgjaogfceg)                             | Same                                                                                 |
| find+                                                 | [find+](https://chromewebstore.google.com/detail/fddffkdncgkkdjobemgbpojjeffmmofb)                                | Same                                                                                 |
| Checkmarks                                            | [Bookmarks clean up](https://chromewebstore.google.com/detail/oncbjlgldmiagjophlhobkogeladjijl)                   | Broken-link and duplicate checking; not the same favicon workflow                    |
| Youtube-shorts block                                  | [Youtube-shorts block](https://chromewebstore.google.com/detail/jiaopdjbehhjgokpphdfgmapkobbnmjp)                 | Same                                                                                 |
| Week Ly                                               | [Week Number Finder](https://chromewebstore.google.com/detail/innakhnibpcngaibnijgkeghiekgikla)                   | ISO week badge and calendar                                                          |
| Qwant                                                 | [Qwant](https://chromewebstore.google.com/detail/kplfenefaakjhjkklghidleljeocgdap)                                | Same search-engine extension                                                         |
| Turbo Download Manager                                | [Turbo Download Manager](https://chromewebstore.google.com/detail/pabnknalmhfecdheflmcaehlepmhjlaa)               | Same                                                                                 |
| JSONView                                              | [JSONView](https://chromewebstore.google.com/detail/gmegofmjomhknnokphhckolhcffdaihd)                             | Same                                                                                 |
| Save as PDF                                           | [Save as PDF](https://chromewebstore.google.com/detail/kpdjmbiefanbdgnkcikhllpmjnnllbbc)                          | Same PDFCrowd service; sends page information to its conversion service              |
| wiki.gg Redirect                                      | [wiki.gg Redirect](https://chromewebstore.google.com/detail/cngoemokfjekjkmajenlaokhnmmiinca)                     | Same                                                                                 |
| I still don't care about cookies                      | [I still don't care about cookies](https://chromewebstore.google.com/detail/edibdbjcniadpccecjdfdjjppcpchdlm)     | Same; hiding a banner does not necessarily reject cookies                            |
| Tab Counter                                           | [Tab Counter](https://chromewebstore.google.com/detail/mnkmfefaigfcieehggcbfabgkjijigbc)                          | Different publisher; same basic counting function                                    |
| CanvasBlocker                                         | [Canvas Blocker - Fingerprint Protect](https://chromewebstore.google.com/detail/nomnklagbgmgghhjidfhnoelnjfndfpd) | Different product; narrower canvas protection, not equivalent fingerprint protection |
| Text to Speech (TTS) and unnamed Text-to-Speech popup | [Text to Speech (TTS)](https://chromewebstore.google.com/detail/cpnomhnclohkhnikegipapofcjihldck)                 | Original TTS product covers both functions                                           |
| Vimium                                                | [Vimium](https://chromewebstore.google.com/detail/dbepggeogbaibhgnhhndojpepiihcmeb)                               | Same                                                                                 |
| Remove YouTube End Cards                              | [Remove YouTube End Cards](https://chromewebstore.google.com/detail/mfengiknfnndchbhjmgjjffjndklkpcm)             | Same                                                                                 |
| Unhook                                                | [Unhook](https://chromewebstore.google.com/detail/khncfooichmfjbepaaaebmommgaepoid)                               | Same                                                                                 |
| Search by Image                                       | [Search by Image](https://chromewebstore.google.com/detail/cnojnbdhbhnkbcieeekonklommdnndci)                      | Same                                                                                 |
| X Nitter Redirect and Twitter to Nitter               | [X Nitter Redirect](https://chromewebstore.google.com/detail/poidplhkjjdljklegndmiccdbephbcjp)                    | One redirect extension instead of two; depends on working Nitter instances           |
| Sort tabs advanced                                    | [Tab Sorter](https://chromewebstore.google.com/detail/faghfoppoimhmffaephmideccaidpagj)                           | Similar sorting, without Firefox container sorting                                   |
| SponsorBlock                                          | [SponsorBlock](https://chromewebstore.google.com/detail/mnjggcdmjocbbbhaepdhchncahnbgone)                         | Same                                                                                 |
| EuroSaver                                             | [EuroSaver](https://chromewebstore.google.com/detail/ofiokjopppicpjjnklicjlnenhabhfhf)                            | Same; affiliate promotions may apply                                                 |
| Tab Session Manager                                   | [Tab Session Manager](https://chromewebstore.google.com/detail/iaiomicjabeggjcfkbimgmglanimpnae)                  | Same; saved sessions are not imported                                                |
| Enhancer for YouTube                                  | [Enhancer for YouTube](https://chromewebstore.google.com/detail/ponfpcnoihfmfllpaingbgckeeldkhle)                 | Same                                                                                 |
| TWP                                                   | [TWP](https://chromewebstore.google.com/detail/gkkkcomfmldkigajkmljnbpiajbpbgdg)                                  | Official MV3 version                                                                 |
| Don't track me Google                                 | [Don't track me Google](https://chromewebstore.google.com/detail/gdbofhhdmcladcmmfjolgndfkpobecpg)                | Same                                                                                 |
| uBlock Origin                                         | [uBlock Origin Lite](https://chromewebstore.google.com/detail/ddkjiahejlhfcafbddmgiahcphecmpfh)                   | Official MV3 alternative; reduced capabilities, not full uBO                         |
| tabStats                                              | [Tabs/Windows Counter and Stats](https://chromewebstore.google.com/detail/oihkkgbnlimoffcljflafghgmaocambp)       | Partial alternative with counts and charts                                           |
| Augmented Steam                                       | [Augmented Steam](https://chromewebstore.google.com/detail/dnhpnfgdlenaccegplpojghhmaamnnfp)                      | Same                                                                                 |
| DownThemAll!                                          | [DownThemAll!](https://chromewebstore.google.com/detail/nljkibfhlpcnanjgbnlnbjecgicbjkge)                         | Same                                                                                 |
| Orange Juice                                          | [Orange Juice](https://chromewebstore.google.com/detail/jojpnpkbdjfpjjgjhdccgpbifipacaii)                         | Same                                                                                 |
| NoScript                                              | [NoScript](https://chromewebstore.google.com/detail/doojmbjmlfjjnbmnoijecmcbfeoakpjm)                             | Same product; Chromium lacks Firefox's XSS checker and TabGuard                      |
| Violentmonkey                                         | [Violentmonkey](https://chromewebstore.google.com/detail/jinjaccalgkegednnccohejagnlnfdag)                        | Official MV3 version; enable “Allow user scripts” in extension details               |
| Dark Reader                                           | [Dark Reader](https://chromewebstore.google.com/detail/eimadpbcbfnmbkopoojfekhnkhdbieeh)                          | Same                                                                                 |
| Read Aloud                                            | [Read Aloud](https://chromewebstore.google.com/detail/hdhinadidafjejdhmfkjgnolgimiaplp)                           | Same; some optional voices use cloud services                                        |
| Reddit Enhancement Suite                              | [Reddit Enhancement Suite](https://chromewebstore.google.com/detail/kbmfpngjjgdllneeigpgjifpgocmfgmb)             | Same; primarily for old Reddit                                                       |
| Return YouTube Dislike                                | [Return YouTube Dislike](https://chromewebstore.google.com/detail/gebbhagfogifgggkldgodflihgfeippi)               | Same                                                                                 |
| ClearURLs                                             | [Neat URL](https://chromewebstore.google.com/detail/jchobbjgibcahbheicfocecmhocglkco)                             | MV3 tracking-parameter cleaner; not all ClearURLs features                           |
| Flagfox                                               | [Country Flags & IP Whois](https://chromewebstore.google.com/detail/bffjckjhidlcnenenacdahhpbacpgapo)             | Similar server-country lookup; optional external lookup services                     |

## Native features and unavailable equivalents

| Firefox extension           | Chrome treatment                                                                                                                |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| PyPI Search                 | Native site-search shortcut: type `@pypi`, Space or Tab, then the query. User-editable policy entry.                            |
| Text Fragment               | Chrome's native “Copy link to highlight” replaces the basic function.                                                           |
| Chrome Mask                 | Unnecessary: the browser already is Chrome.                                                                                     |
| Containerise                | No equivalent per-tab cookie containers. Separate Chrome profiles offer partial isolation, without automatic container routing. |
| Facebook Container          | No equivalent. Use a separate profile for Facebook if isolation is required.                                                    |
| TikTok Container            | No equivalent. Use a separate profile for TikTok if isolation is required.                                                      |
| Amazon Container            | No equivalent. Use a separate profile for Amazon if isolation is required.                                                      |
| Port Authority              | No verified maintained Chrome equivalent. Chrome and NoScript protections are not equivalent to the Firefox add-on.             |
| Internet Archive Downloader | No verified current official store entry. The developer distributes a Chrome CRX separately; not sideloaded.                    |
| Age verification bypass     | Developer states that Chrome is unsupported, including sideloading. No verified substitute configured.                          |
| Codex Usage Viewer          | Locally installed Firefox extension; no verified Chrome distribution. Not copied or rewritten.                                  |
| Snap Links                  | Disabled in Firefox; not enabled in Chrome.                                                                                     |
| YouTube Redux               | Disabled in Firefox; not enabled in Chrome.                                                                                     |

Firefox extension settings, userscripts, cookies, credentials, bookmarks,
browsing history, saved sessions and container assignments have not been
migrated. This configuration installs extension products, not Firefox profile
data. No separate Chrome isolation profiles have been created.

## Sources

- [Chrome extension installation on Linux](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions)
- [ExtensionSettings policy schema](https://raw.githubusercontent.com/chromium/chromium/main/components/policy/resources/templates/policy_definitions/Extensions/ExtensionSettings.yaml)
- [SiteSearchSettings policy schema](https://raw.githubusercontent.com/chromium/chromium/main/components/policy/resources/templates/policy_definitions/Miscellaneous/SiteSearchSettings.yaml)
- [uBlock Origin Lite](https://github.com/uBlockOrigin/uBOL-home/wiki)
- [NoScript browser differences](https://noscript.net/usage/)
- [Internet Archive Downloader installation](https://github.com/elementdavv/internet_archive_downloader)
- [Age verification bypass Chrome limitation](https://github.com/helloyanis/age-verification-bypass)
- [ClearURLs Chromium limitations](https://docs.clearurls.xyz/troubleshooting)
- [Neat URL source](https://github.com/Smile4ever/Neat-URL)
