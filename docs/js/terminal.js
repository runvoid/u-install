(function() {
  const body = document.getElementById('terminal-body');
  const input = document.getElementById('term-input');
  if (!body || !input) return;

  const STORAGE_KEY = 'u-install-demo-db';
  const DISTRO = 'arch';

  function loadDB() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}; }
    catch { return {}; }
  }
  function saveDB(db) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(db));
  }
  function getDB() {
    const db = loadDB();
    if (!db.packages) db.packages = {};
    if (!db.config) db.config = { prefer_source: 'auto', colors: true };
    return db;
  }

  const knownPackages = {
    'firefox': { native: 'firefox 123.0-1', nix: 'firefox-123.0', aur: null },
    'neovim': { native: 'neovim 0.9.5-1', nix: 'neovim-0.9.5', aur: null },
    'nodejs': { native: 'nodejs 21.7.1-1', nix: 'nodejs-21.7.1', aur: null },
    'htop': { native: 'htop 3.3.0-1', nix: 'htop-3.3.0', aur: null },
    'docker': { native: 'docker 1:25.0.3-1', nix: 'docker-25.0.3', aur: null },
    'vlc': { native: 'vlc 3.0.20-1', nix: 'vlc-3.0.20', aur: null },
    'gimp': { native: 'gimp 2.10.36-1', nix: 'gimp-2.10.36', aur: null },
    'brave-bin': { native: null, nix: null, aur: 'brave-bin 1:1.60.114-1' },
    'visual-studio-code-bin': { native: null, nix: null, aur: 'visual-studio-code-bin 1.85.1-1' },
    'spotify': { native: null, nix: 'spotify-1.2.26', aur: 'spotify 1:1.2.26.1187-1' },
    'discord': { native: null, nix: 'discord-0.0.40', aur: 'discord 0.0.40-1' },
    'steam': { native: 'steam 1.0.0.78-1', nix: 'steam-1.0.0.78', aur: null },
    'obs-studio': { native: 'obs-studio 30.0.2-1', nix: 'obs-studio-30.0.2', aur: null },
    'telegram-desktop': { native: 'telegram-desktop 4.14.9-1', nix: 'telegram-desktop-4.14.9', aur: null },
  };

  function print(text, cls) {
    const div = document.createElement('div');
    div.className = 'term-line' + (cls ? ' ' + cls : '');
    div.innerHTML = text;
    body.appendChild(div);
    body.scrollTop = body.scrollHeight;
  }
  function printPrompt() {
    print('<span class="term-prompt">$</span> <span class="term-cursor">_</span>');
  }
  function clearCursor() {
    const cursors = body.querySelectorAll('.term-cursor');
    cursors.forEach(c => c.remove());
  }

  function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
  }

  async function typeEffect(text, cls) {
    clearCursor();
    const div = document.createElement('div');
    div.className = 'term-line' + (cls ? ' ' + cls : '');
    body.appendChild(div);
    for (let i = 0; i < text.length; i++) {
      div.textContent += text[i];
      body.scrollTop = body.scrollHeight;
      await sleep(8);
    }
  }

  async function progressBar(label, steps) {
    for (let i = 1; i <= steps; i++) {
      const pct = Math.round((i / steps) * 100);
      const bar = '█'.repeat(i) + '░'.repeat(steps - i);
      clearCursor();
      print('<span class="term-dim">' + label + ' [' + bar + '] ' + pct + '%</span>');
      await sleep(120 + Math.random() * 80);
    }
  }

  // ===== Commands =====
  const commands = {};

  commands['u-help'] = async function() {
    print('<span class="term-info">u-install 1.2.1 — a universal package helper</span>');
    print('');
    print('Commands:');
    print('  <span class="term-ok">u-install</span>    Install packages (native / Nix / AUR, auto-detected)');
    print('  <span class="term-ok">u-uninstall</span>  Remove packages tracked by u-install');
    print('  <span class="term-ok">u-update</span>     Update system, Nix and AUR packages');
    print('  <span class="term-ok">u-search</span>     Search a package across all sources');
    print('  <span class="term-ok">u-list</span>       List packages tracked in the local database');
    print('  <span class="term-ok">u-peek</span>       Inspect AUR package metadata without building it');
    print('  <span class="term-ok">u-stats</span>      Show statistics about tracked packages');
    print('  <span class="term-ok">u-doctor</span>     Diagnose the environment and configuration');
    print('  <span class="term-ok">u-export</span>     Export config + packages to a portable .u file');
    print('  <span class="term-ok">u-import</span>     Restore config + packages from a .u file');
    print('  <span class="term-ok">u-help</span>       Show this overview');
    print('');
    print("Run 'COMMAND --help' for details, e.g. 'u-install --help'.");
  };

  commands['u-install'] = async function(args) {
    const db = getDB();
    const pkg = args[0];
    if (!pkg) {
      print('<span class="term-err">Usage: u-install &lt;package&gt;</span>');
      return;
    }
    if (pkg.startsWith('@')) {
      print('<span class="term-info">Installing group: ' + pkg + '</span>');
      await sleep(300);
      print('<span class="term-ok">Group installed successfully.</span>');
      return;
    }
    if (db.packages[pkg]) {
      print('<span class="term-warn">Previously installed via ' + db.packages[pkg].source + '</span>');
      print('<span class="term-dim">Reinstalling...</span>');
    }
    const info = knownPackages[pkg];
    let source = 'native';
    let version = 'latest';
    let force = '';
    for (const a of args.slice(1)) {
      if (a === '--nix') force = 'nix';
      if (a === '--aur') force = 'aur';
      if (a === '--native') force = 'native';
    }
    if (force) source = force;
    else if (info) {
      if (info.native) source = 'native';
      else if (info.nix) source = 'nix';
      else if (info.aur) source = 'aur';
    }
    if (info && info[source]) version = info[source];

    print('<span class="term-info">Distribution: ' + DISTRO + '</span>');
    print('<span class="term-info">Processing: ' + pkg + (version !== 'latest' ? ' @ ' + version : '') + '</span>');
    await sleep(200);

    if (source === 'native') {
      await progressBar('pacman -S ' + pkg, 12);
    } else if (source === 'nix') {
      await progressBar('nix-env -iA nixpkgs.' + pkg, 10);
    } else if (source === 'aur') {
      print('<span class="term-info">Cloning AUR package ' + pkg + '...</span>');
      await sleep(400);
      await progressBar('makepkg -si', 14);
    }

    db.packages[pkg] = { source: source, version: version, date: new Date().toISOString().split('T')[0] };
    saveDB(db);
    print('<span class="term-ok">[u-install] Installed via ' + source + '</span>');
  };

  commands['u-uninstall'] = async function(args) {
    const db = getDB();
    const pkg = args[0];
    if (!pkg) {
      print('<span class="term-err">Usage: u-uninstall &lt;package&gt;</span>');
      return;
    }
    if (!db.packages[pkg]) {
      print('<span class="term-err">\'' + pkg + '\' not found in database</span>');
      return;
    }
    const src = db.packages[pkg].source;
    print('<span class="term-info">Removing: ' + pkg + '</span>');
    await sleep(200);
    if (src === 'native') await progressBar('pacman -Rns ' + pkg, 8);
    else if (src === 'nix') await progressBar('nix-env -e ' + pkg, 6);
    else if (src === 'aur') await progressBar('pacman -Rns ' + pkg, 8);
    delete db.packages[pkg];
    saveDB(db);
    print('<span class="term-ok">[u-install] Removed ' + pkg + '</span>');
  };

  commands['u-list'] = async function(args) {
    const db = getDB();
    const pkgs = Object.entries(db.packages);
    let filter = '';
    for (const a of args) {
      if (a === '--native') filter = 'native';
      if (a === '--nix') filter = 'nix';
      if (a === '--aur') filter = 'aur';
    }
    const filtered = filter ? pkgs.filter(([_, v]) => v.source === filter) : pkgs;
    print('<span class="term-info">=== Installed packages ===</span>');
    if (filtered.length === 0) {
      print('<span class="term-dim">No packages tracked yet.</span>');
      return;
    }
    print('');
    print('  <span class="term-dim">PACKAGE                   SOURCE   DATE</span>');
    print('  <span class="term-dim">------------------------  -------- ----------</span>');
    for (const [name, data] of filtered) {
      print('  ' + name.padEnd(24) + ' ' + data.source.padEnd(8) + ' ' + (data.date || 'unknown'));
    }
    print('');
    print('<span class="term-ok">' + filtered.length + ' package(s)' + (filter ? ' (' + filter + ')' : ' total') + '.</span>');
  };

  commands['u-search'] = async function(args) {
    const pkg = args[0];
    if (!pkg) {
      print('<span class="term-err">Usage: u-search &lt;package&gt;</span>');
      return;
    }
    print('<span class="term-info">Searching: ' + pkg + '</span>');
    await sleep(300);
    print('');
    print('  <span class="term-dim">SOURCE     PACKAGE              VERSION         STATUS</span>');
    print('  <span class="term-dim">---------- -------------------- --------------- ----------</span>');
    const info = knownPackages[pkg];
    const nv = info && info.native ? info.native.split(' ')[1] : '';
    const ns = info && info.native ? 'available' : 'not found';
    print('  native     ' + pkg.padEnd(20) + ' ' + nv.padEnd(15) + ' ' + ns);
    const nxv = info && info.nix ? info.nix.split('-').slice(1).join('-') : '';
    const nxs = info && info.nix ? 'available' : 'not found';
    print('  nix        ' + pkg.padEnd(20) + ' ' + nxv.padEnd(15) + ' ' + nxs);
    const av = info && info.aur ? info.aur.split(' ')[1] : '';
    const as = info && info.aur ? 'available' : 'not found';
    print('  aur        ' + pkg.padEnd(20) + ' ' + av.padEnd(15) + ' ' + as);
    print('');
  };

  commands['u-export'] = async function(args) {
    const db = getDB();
    const filename = args[0] || 'configuration.u';
    print('<span class="term-info">Exporting to ' + filename + '...</span>');
    await sleep(300);
    let out = '# u-install export\n# format: u2\n\n[meta]\n';
    out += 'version=1.2.1\nexported=' + new Date().toISOString().split('T')[0] + '\n';
    out += 'hostname=demo-pc\n\n[config]\n';
    out += 'prefer_source=' + db.config.prefer_source + '\n';
    out += 'colors=' + db.config.colors + '\n\n[packages]\n';
    for (const [name, data] of Object.entries(db.packages)) {
      out += name + '|' + data.source + '|' + (data.version || 'latest') + '\n';
    }
    print('<span class="term-ok">Exported ' + Object.keys(db.packages).length + ' package(s) to ' + filename + '</span>');
    print('<span class="term-dim">Apply on another machine with: u-import ' + filename + '</span>');
  };

  commands['u-import'] = async function(args) {
    const file = args[0];
    if (!file) {
      print('<span class="term-err">Usage: u-import &lt;file.u&gt;</span>');
      return;
    }
    print('<span class="term-info">Importing from: ' + file + '</span>');
    await sleep(200);
    print('<span class="term-warn">Demo: simulating import of sample packages...</span>');
    const sample = { 'htop': 'native', 'nodejs': 'nix', 'brave-bin': 'aur' };
    const db = getDB();
    for (const [pkg, src] of Object.entries(sample)) {
      print('<span class="term-info">Installing ' + pkg + ' (' + src + ')...</span>');
      await sleep(400);
      db.packages[pkg] = { source: src, version: 'latest', date: new Date().toISOString().split('T')[0] };
    }
    saveDB(db);
    print('<span class="term-ok">Import complete. 3 package(s) installed.</span>');
  };

  commands['u-peek'] = async function(args) {
    const pkg = args[0];
    if (!pkg) {
      print('<span class="term-err">Usage: u-peek &lt;package&gt;</span>');
      return;
    }
    print('<span class="term-info">Peeking AUR: ' + pkg + '</span>');
    await sleep(300);
    const info = knownPackages[pkg];
    if (!info || !info.aur) {
      print('<span class="term-err">AUR package not found: ' + pkg + '</span>');
      return;
    }
    print('  # Package: ' + pkg);
    print('  # Version: ' + (info.aur.split(' ')[1] || 'unknown'));
    print('  # Maintainer: demo-user');
    print('  # Last update: 2026-08-01');
    print('  # Votes: 142');
    print('  # Popularity: 8.5%');
    print('  # Out of date: no');
    print('  # PKGBUILD size: 4.2KB');
    print('  # Security flags: none');
    print('');
  };

  commands['u-stats'] = async function() {
    const db = getDB();
    const pkgs = Object.keys(db.packages);
    print('<span class="term-info">=== u-install Statistics ===</span>');
    print('');
    print('  Total tracked: ' + pkgs.length);
    print('  Native: ' + pkgs.filter(p => db.packages[p].source === 'native').length);
    print('  Nix: ' + pkgs.filter(p => db.packages[p].source === 'nix').length);
    print('  AUR: ' + pkgs.filter(p => db.packages[p].source === 'aur').length);
    print('');
    print('  Config: ~/.config/u-install/u-install.conf');
    print('  Prefer source: ' + db.config.prefer_source);
  };

  commands['u-doctor'] = async function() {
    print('<span class="term-info">=== u-install Doctor ===</span>');
    print('');
    print('[Dependencies]');
    print('  [OK] bash');
    print('  [OK] curl');
    print('  [OK] git');
    print('  [OK] sudo/doas available');
    print('');
    print('[System]');
    print('  Distribution: ' + DISTRO);
    print('');
    print('[Nix]');
    print('  [INFO] Nix not installed');
    print('');
    print('[AUR]');
    print('  [OK] Arch-based');
    print('  [OK] makepkg');
    print('  [OK] git');
    print('');
    print('[Database]');
    const db = getDB();
    print('  [OK] ' + Object.keys(db.packages).length + ' packages tracked');
    print('');
    print('[Summary]');
    print('<span class="term-ok">Healthy.</span>');
  };

  commands['u-update'] = async function() {
    print('<span class="term-info">=== Native Update ===</span>');
    await progressBar('pacman -Syu', 15);
    print('<span class="term-ok">System updated.</span>');
    print('');
    print('<span class="term-info">=== Nix Update ===</span>');
    print('<span class="term-warn">Nix not installed. Skipping.</span>');
    print('');
    print('<span class="term-info">=== AUR Update ===</span>');
    const db = getDB();
    const aurPkgs = Object.entries(db.packages).filter(([_, v]) => v.source === 'aur');
    if (aurPkgs.length === 0) {
      print('<span class="term-dim">No AUR packages cached.</span>');
    } else {
      for (const [pkg, _] of aurPkgs) {
        print('<span class="term-info">Updating AUR ' + pkg + '...</span>');
        await sleep(300);
        print('<span class="term-ok">' + pkg + ' is up to date.</span>');
      }
    }
    print('');
    print('<span class="term-ok">Update complete.</span>');
  };

  commands['clear'] = async function() {
    body.innerHTML = '';
  };

  // ===== Input Handler =====
  async function handleCommand(raw) {
    const trimmed = raw.trim();
    if (!trimmed) return;
    clearCursor();
    print('<span class="term-prompt">$</span> ' + trimmed);
    const parts = trimmed.split(/\s+/);
    const cmd = parts[0];
    const args = parts.slice(1);

    if (commands[cmd]) {
      await commands[cmd](args);
    } else {
      print('<span class="term-err">Command not found: ' + cmd + '</span>');
      print('<span class="term-dim">Type u-help for available commands.</span>');
    }
    printPrompt();
  }

  input.addEventListener('keydown', async function(e) {
    if (e.key === 'Enter') {
      const val = input.value;
      input.value = '';
      await handleCommand(val);
    }
  });

  // Expose for hint buttons
  window.termRun = async function(cmd) {
    input.value = '';
    await handleCommand(cmd);
    input.focus();
  };
  window.termClear = function() {
    body.innerHTML = '';
    printPrompt();
    input.focus();
  };

  // Init
  print('<span class="term-info">u-install 1.2.1 demo terminal</span>');
  print('<span class="term-dim">Packages are stored in your browser (localStorage).</span>');
  print('<span class="term-dim">Try: u-help, u-install firefox, u-search neovim, u-list</span>');
  print('');
  printPrompt();
  input.focus();
})();
