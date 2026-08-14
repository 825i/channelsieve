# ChannelSieve

WebExtension for Chrome and Firefox.  
Filter and block unwanted content from YouTube™.

> ### About this fork
>
> This is a maintenance fork of [amitbl/blocktube](https://github.com/amitbl/blocktube), whose last
> release was v0.4.8 (7 Feb 2026). It fixes the Firefox Manifest V3 problem that makes the extension
> install successfully and then do nothing at all, and it removes a destructive bug in the build
> script. See [CHANGES-FORK.md](CHANGES-FORK.md) for the full list.
>
> **:warning: If you cloned the upstream repo, do not run its `tools/build.sh`.** In upstream it
> deletes an unintended directory when the repository path contains a space — see
> [Security note](#security-note-upstream-toolsbuildsh) below.
>
> The blocking engine itself is unchanged and still works against current YouTube.

## Installed but nothing happens? (Firefox)

If ChannelSieve shows as installed in Firefox but has no toolbar icon, no settings, and no
"Block Channel" / "Block Video" entries in YouTube's three-dot menu, neither the extension nor
YouTube is broken. Two things are going on, and both are one-time fixes:

**1. It has no permission to touch YouTube.** In Manifest V3, Firefox treats host permissions as
user-controlled, and they are not always granted at install. ChannelSieve works entirely through
content scripts, so with no host access nothing injects and it silently does nothing.

* `about:addons` → **Extensions** → ChannelSieve → **Permissions** → enable access for
  `www.youtube.com` and `m.youtube.com`, **or**
* the Extensions (puzzle-piece) button → ChannelSieve → gear → *Always Allow on www.youtube.com*, **or**
* open the ChannelSieve popup — this fork adds a **Grant access to YouTube** button that appears
  whenever the permission is missing.

Then reload any open YouTube tab; content scripts only inject at `document_start`.

**2. The toolbar icon is in the puzzle-piece panel.** Firefox does not auto-place Manifest V3
action buttons on the toolbar. Click the Extensions (puzzle-piece) button, then right-click
ChannelSieve → **Pin to Toolbar**. Settings are also always reachable from
`about:addons` → ChannelSieve → **Preferences**.

To confirm it is running, open a YouTube tab and look for `ChannelSieve Init` in the web console.

## Extension features

* Block videos via: **Video Title** / **Channel Name** / **Channel ID** / **Video ID**
* Block comments via **User** / **Comment content**
* Block videos within YouTube using context menus
* Blocked videos do not appear anywhere on the site
* Support for `m.youtube.com` on Firefox for Android and Kiwi Browser
* Block complete channels
* Supports both keywords and raw Regex
* Does not break or limit any features of YouTube like playlist or autoplay
* Hide and block the Trending section
* Protect extension options with a password
* Filtering is done before any DOM rendering

## Install

* **Firefox** — download the signed `.xpi` from
  [Releases](https://github.com/825i/channelsieve/releases). It is self-distributed and signed by
  Mozilla, so it installs normally with no changes to your browser's security settings.
* **Chrome** — not published to the Web Store. Build it with
  `.\tools\build.ps1 -Browser chrome` (or `./tools/build.sh chrome`) and
  [load it unpacked](https://developer.chrome.com/docs/extensions/mv3/getstarted/development-basics/#load-unpacked).

Upstream BlockTube, which this is forked from, is published at the
[Chrome Web Store](https://chrome.google.com/webstore/detail/blocktube/bbeaicapbccfllodepmimpkgecanonai)
and [Firefox AMO](https://addons.mozilla.org/en-US/firefox/addon/blocktube/).

## FAQ
  
* What is the difference between "Channel ID" and "Channel Name"  
  Channel names on YouTube are not unique and can be duplicated/changed  
  whereas Channel ID is a unique identification string that never changes.  
  If you want to block a specific single channel the preferred method is using it's ID,  
  If you want to block multiple channels sharing similar name use it's name.

* How can I get a channel's ID?  
  Channel ID looks like this: UCXXXXXXXXXXXXXXXX  
  To get it, simply browse to a channel page and look at the URL `/channel/UCXXXXXXXXXXXXXXXXXXXX`  
  If the URL is `/user/BadChannelExample` use [This site](https://vabs.github.io/youtube-channel-name-converter/) to convert the username to the channel ID

* How to block comments from specific user?  
  Blocked channels comments are removed as well, so just add the user's name/channel ID
  to your filters

* What is the behaviour when browsing blocked channel?  
  User will be redirected to YouTube homepage.

* What is the behaviour when browsing blocked video?  
  You can choose between two options:
  - Block the entire page and leave a custom message
  - Auto redirect user to the next video

* How can I ensure this extension cannot be bypassed?   
  TODO

## Development & Build

There is no build toolchain to install — the extension is plain JavaScript. Building only copies
the sources, substitutes the version placeholder, and zips the result.

*Linux / macOS* (needs `bash` and `zip`)
```
git clone https://github.com/825i/channelsieve
cd channelsieve

### Make your changes ###

./tools/build.sh firefox
./tools/build.sh chrome

# Output
./dist/firefox/channelsieve_firefox_v<VERSION>.zip
./dist/chrome/channelsieve_chrome_v<VERSION>.zip
```

*Windows* (PowerShell; added in this fork, since Windows has no `zip` binary)
```
git clone https://github.com/825i/channelsieve
cd channelsieve

.\tools\build.ps1 -Browser firefox
.\tools\build.ps1 -Browser chrome

# Output — a ready-to-load .xpi plus the unpacked directory
.\dist\channelsieve_firefox_v<VERSION>.xpi
.\dist\firefox\
```
Pass `-Force` to replace an existing build directory; without it the script refuses rather than
deleting anything. It writes only inside `dist\`.

*Temporary installation / debugging*

* Firefox: `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on** → pick the `.xpi`
  or the unpacked `manifest.json`.
  ([docs](https://extensionworkshop.com/documentation/develop/temporary-installation-in-firefox/))
* Chrome: [load unpacked](https://developer.chrome.com/docs/extensions/mv3/getstarted/development-basics/#load-unpacked)

Note that a temporary add-on is removed when the browser restarts, and its stored blocklist does not
persist — export your filters first. Installing a modified build permanently in release Firefox
requires an AMO signature.

### Security note: upstream `tools/build.sh`

Upstream's build script could destroy data. It computed its own location with unquoted expansions
and then deleted with an unquoted variable:

```bash
BASEDIR=$(dirname $(dirname $SCRIPT))   # $SCRIPT unquoted
clean() { rm -rf $DEST; }               # $DEST unquoted
```

If the repository path contained a space, `$SCRIPT` word-split into two arguments, `dirname`
received two operands and printed two lines, and `$DEST` became two paths. `build()` calls `clean()`
first, so `rm -rf $DEST` split again and deleted an unintended directory. For a checkout under
`C:\Users\<you>\Documents\Claude Desktop\blocktube` it resolved to:

```
rm -rf /c/Users/<you>  Desktop/blocktube/dist/firefox
```

— removing the entire home directory. Running the script with no arguments also reached `clean()`
with `$DEST` unset.

This fork quotes every expansion, adds `set -euo pipefail`, sets `DEST` before any `clean`, requires
an explicit subcommand, and refuses to delete anything that is not a build directory under
`$BASEDIR/dist`.

## Future work

* User-friendly options UI
* Sync options to cloud provider / enterprise policies
* Whitelist mode
* Dynamic rules (match multiple rules to block a video)

## License

This project is licensed under the GPLv3 License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* Extension Icon from: http://www.designbolts.com/2013/09/08/40-free-shaded-social-media-icons/
