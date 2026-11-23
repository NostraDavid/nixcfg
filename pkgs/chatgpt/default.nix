{
  chatgpt,
  coreutils,
  libGL,
  nodejs,
  python3,
}:
chatgpt.overrideAttrs (old: {
  meta = old.meta // {platforms = ["x86_64-linux"];};
  passthru =
    old.passthru
    // {
      sources.x86_64-linux = rec {
        version = "26.1117.41037";
        src = {
          url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
          hash = "sha256-gw4lG2ykrUX+aQQSenkOjwD3wm7UyAOUc/cyPHxOJpI=";
        };
      };
    };

  dontStrip = false;
  nativeBuildInputs = old.nativeBuildInputs ++ [python3];
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libc.musl-x86_64.so.1"
  ];

  # autoPatchelf moves PT_INTERP beyond detect-libc's 2 KiB scan. Its
  # process.report fallback trips Electron's CFI, so use the glibc watcher.
  # Keep the replacement length unchanged to preserve ASAR offsets.
  postPatch = ''
    grep -aFq 'const family = familySync();' usr/lib/chatgpt/resources/app.asar
    sed -i "s|const family = familySync();|const family = 'glibc'     ;|" usr/lib/chatgpt/resources/app.asar

    # Node's recursive copy preserves the Nix store's read-only mode. The
    # local Work executor must rewrite its copied MCP configuration.
    python3 - <<'PY'
    import mmap
    import re

    with open("usr/lib/chatgpt/resources/app.asar", "r+b") as file, mmap.mmap(file.fileno(), 0) as archive:
        # Nix manages the local node_repl entry. Desktop threads still receive
        # the app's own runtime config, including their browser credentials.
        config_write = re.compile(
            rb'\.\.\.\((?P<alias>[\w$]+)=(?P<config>[\w$]+),\[\{keyPath:(?P<key>`mcp_servers\.\$\{[\w$]+\.[\w$]+\}`),'
            rb'mergeStrategy:"replace",value:(?P=alias)\?\.\[(?P=key)\]\?\?null\},'
            rb'(?P<cleanup>\.\.\.[\w$]+\.map\([^{}]+\{keyPath:`shell_environment_policy\.set\.\$\{[\w$]+\}`,mergeStrategy:"replace",value:null\}\)\))\]\)'
            rb'(?P<tail>,\{keyPath:`mcp_servers\.[^;]+\];return await (?P<connection>[\w$]+)\.sendAppServerRequest\("config/batchWrite",\{edits:[\w$]+,expectedVersion:null,)'
            rb'filePath:null,'
        )
        matches = list(config_write.finditer(archive))
        assert len(matches) == 1, "desktop node_repl config write changed"
        match = matches[0]
        # The omitted filePath defaults to the same user config. Reuse the
        # key expression so the replacement fits without moving ASAR offsets.
        after = (
            b'...' + match['connection'] + b'.hostConfig.kind==="local"?[]:[{keyPath:'
            + match['alias'] + b'=' + match['key'] + b',mergeStrategy:"replace",value:'
            + match['config'] + b'?.[' + match['alias'] + b']??null}],'
            + match['cleanup'] + match['tail']
        )
        assert len(after) <= len(match[0]), "desktop config patch changes ASAR offsets"
        archive[match.start():match.end()] = after.ljust(len(match[0]))

        initializer = re.search(rb"async function(?: ([\w$]+))?\(\{executorPluginRoot:", archive)
        assert initializer is not None, "executor plugin initializer not found"
        start = initializer.start()
        if initializer.group(1):
            end = archive.find(b"async function ", initializer.end())
        else:
            end = archive.find(b"}({executorPluginRoot:", initializer.end())
            assert end >= 0, "executor plugin initializer call not found"
            end += 1
        assert end > start, "executor plugin initializer boundary not found"
        before = archive[start:end]
        # Recent bundles call module factories and use different local names.
        factory = re.search(rb'await ([\w$]+)\(\)\.cp\(([\w$]+)\.cwd,([\w$]+),', before)
        if factory:
            fs_module, definition, dest = factory.groups()
            path_match = re.search(rb'([\w$]+)\(\)\.join\(' + dest + rb',\1\(\)\.relative\(' + definition + rb'\.cwd,', before)
            assert path_match is not None, "executor path factory not found"
            path_module = path_match.group(1)
            after = before.replace(fs_module + b"().", b"f.").replace(path_module + b"().", b"p.")
            after, count = re.subn(rb'(let ' + definition + rb'=await [\w$]+\([^;]+\));', rb'\1,f=' + fs_module + b'(),p=' + path_module + b'();', after, count=1)
            assert count == 1, "executor definition lookup changed"
            guard = b'"win32"!==process.platform&&('
            assert after.count(guard) == 1, "executor platform guard changed"
            after = after.replace(guard, b'(', 1)
            write = b'await f.writeFile(p.join(' + dest + b',".mcp.json"),'
            assert after.count(write) == 1, "executor configuration write changed"
            after = after.replace(write, b'await f.chmod(p.join(' + dest + b',".mcp.json"),384),' + write, 1)
            config = b'p.join(' + dest + b',".mcp.json")'
            assert after.count(config) == 2 and not re.search(rb'\bc\b', before), "executor config alias collision"
            after = after.replace(config, b'c').replace(b'p=' + path_module + b'();', b'p=' + path_module + b'(),c=' + config + b';', 1)
        else:
            fs_alias = re.search(rb"await ([\w$]+)\.default\.cp\(n\.cwd,e,", before)
            path_alias = re.search(rb"n\.command=([\w$]+)\.default\.join\(e,", before)
            assert fs_alias is not None and path_alias is not None, "executor module aliases not found"
            fs_module, path_module = fs_alias.group(1), path_alias.group(1)
            after, count = re.subn(
            rb"(let n=await [\w$]+\(\{useWsl:!1,resourcesPath:t\}\));",
            rb"\1,f=" + fs_module + b".default,p=" + path_module + b".default;",
            before,
        )
            assert count == 1, "executor definition lookup changed"
            after = after.replace(
            b"process.platform!==`win32`&&(n.command=" + path_module + b".default.join(e," + path_module + b".default.relative(n.cwd,n.command)))",
            b"n.command=" + path_module + b".default.join(e," + path_module + b".default.relative(n.cwd,n.command))",
        ).replace(fs_module + b".default.", b"f.").replace(path_module + b".default.", b"p.").replace(
            b"await f.writeFile(p.join(e,`.mcp.json`),",
            b"await f.chmod(p.join(e,`.mcp.json`),384),await f.writeFile(p.join(e,`.mcp.json`),",
        )
        assert b"await f.chmod(" in after, "executor permissions patch did not apply"
        assert len(after) <= len(before), "executor permissions patch changes ASAR offsets"
        archive[start:end] = after.ljust(len(before))

        # Marketplace materialization edits copied plugin metadata and removes
        # disabled skills. Node's cp preserves immutable Nix-store permissions.
        helper = re.search(
            rb"async function(?: ([\w$]+))?\(e,t\)\{if\([\w$]+\.default\.platform===`darwin`\)\{await ([\w$]+)\(`/usr/bin/ditto`",
            archive,
        )
        if helper is None:
            helper = re.search(rb'async function(?: ([\w$]+))?\(e,t\)\{if\("darwin"===[\w$]+\(\)\.platform\)return void await ([\w$]+)\("/usr/bin/ditto"', archive)
        assert helper is not None, "marketplace copy helper not found"
        start = helper.start()
        name, runner = helper.groups()
        if name:
            end = archive.find(b"async function ", helper.end())
        else:
            end = archive.find(b"}(", helper.end())
            assert end >= 0, "marketplace copy helper call not found"
            end += 1
        assert end > start, "marketplace copy helper boundary not found"
        before = archive[start:end]
        assert re.search(rb"await [\w$]+(?:\.default|\(\))\.cp\(e,t,", before), "marketplace copy helper changed"
        after = b'async function' + (b' ' + name if name else b"") + b'(e,t){await ' + runner + b'(`${coreutils}/bin/cp`,[`-R`,`--`,e+`/.`,t]);await ' + runner + b'(`${coreutils}/bin/chmod`,[`-R`,`u+w`,`--`,t])}'
        assert len(after) <= len(before), "marketplace permissions patch changes ASAR offsets"
        archive[start:end] = after.ljust(len(before))
    PY
  '';

  # Work and the CUA wrappers use the matching bundled Node, Codex and plugins.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R --no-preserve=ownership usr/. "$out/"
    runHook postInstall
  '';

  nativeInstallCheckInputs = [nodejs];
  installCheckPhase = ''
    runHook preInstallCheck
    node ${./check-executor.cjs} "$out/lib/chatgpt/resources/app.asar"
    runHook postInstallCheck
  '';

  # Electron dlopens libGL, so autoPatchelfHook cannot discover this dependency.
  postFixup = ''
    wrapProgram "$out/lib/chatgpt/codex-launcher" \
      --prefix LD_LIBRARY_PATH : "${libGL}/lib"
  '';
})
