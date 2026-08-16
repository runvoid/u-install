(function(){const t=document.createElement("link").relList;if(t&&t.supports&&t.supports("modulepreload"))return;for(const n of document.querySelectorAll('link[rel="modulepreload"]'))o(n);new MutationObserver(n=>{for(const s of n)if(s.type==="childList")for(const i of s.addedNodes)i.tagName==="LINK"&&i.rel==="modulepreload"&&o(i)}).observe(document,{childList:!0,subtree:!0});function a(n){const s={};return n.integrity&&(s.integrity=n.integrity),n.referrerPolicy&&(s.referrerPolicy=n.referrerPolicy),n.crossOrigin==="use-credentials"?s.credentials="include":n.crossOrigin==="anonymous"?s.credentials="omit":s.credentials="same-origin",s}function o(n){if(n.ep)return;n.ep=!0;const s=a(n);fetch(n.href,s)}})();const p="1.4.1",u=[{name:"u-install",description:"Install packages from the native package manager, Nix, or the AUR, auto-detecting the best available source.",help:`u-install 1.4.1

Install packages from the native package manager, Nix, or the AUR,
auto-detecting the best available source.

Usage: u-install [OPTIONS] <PACKAGE...>
         u-install @<GROUP>
         u-install --profile <NAME>

Options:
  --native        Force native package manager
  --nix           Force Nix
  --aur           Force AUR (Arch-based only)
  --profile       Install packages from a profile list
  --self-update   Update u-install itself
  --dry-run       Show what would be installed without making changes
  -y, --yes       Assume yes to all prompts
  -V, --version   Show version information
  -h, --help      Show this help message`},{name:"u-uninstall",description:"Remove packages tracked by u-install, using their recorded source.",help:`u-uninstall 1.4.1

Remove packages tracked by u-install, using their recorded source.

Usage: u-uninstall [OPTIONS] <PACKAGE...>

Options:
  -y, --yes      Assume yes to all prompts
  --force        Allow removing critical system packages
  --dry-run      Show what would be removed without making changes
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-update",description:"Update system packages, Nix packages, cached AUR builds, and u-install itself.",help:`u-update 1.4.1

Update system packages, Nix packages, cached AUR builds, and u-install itself.

Usage: u-update [OPTIONS]

Options:
  --system       Update only system packages
  --nix          Update only Nix packages
  --aur          Update only AUR packages
  --self         Update only u-install itself
  --dry-run      Show what would be updated without making changes
  -y, --yes      Assume yes to all prompts
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-upgrade",description:"Upgrade a single tracked package using its recorded source (native, Nix or AUR).",help:`u-upgrade 1.4.1

Upgrade a single tracked package using its recorded source (native, Nix or AUR).

Usage: u-upgrade [OPTIONS] <PACKAGE...>

Options:
  --dry-run      Show what would be upgraded without making changes
  -y, --yes      Assume yes to all prompts
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-search",description:"Search for a package across native, Nix and AUR sources.",help:`u-search 1.4.1

Search for a package across native, Nix and AUR sources.

Usage: u-search [OPTIONS] <PACKAGE...>

Options:
  -i, --install  After searching, pick a source from a menu and install
  --no-cache     Skip the search cache and refresh results
  -V, --version  Show version information
  -h, --help  Show this help message`},{name:"u-peek",description:"Inspect AUR package metadata without cloning or building it. Helps you decide whether an AUR package is worth touching at all.",help:`u-peek 1.4.1

Inspect AUR package metadata without cloning or building it.
Helps you decide whether an AUR package is worth touching at all.

Usage: u-peek [OPTIONS] <PACKAGE...>

Options:
  -V, --version  Show version information
  -h, --help  Show this help message`},{name:"u-list",description:"List packages tracked by u-install (from its database).",help:`u-list 1.4.1

List packages tracked by u-install (from its database).

Usage: u-list [OPTIONS]

Options:
  --native       Show only native packages
  --nix          Show only Nix packages
  --aur          Show only AUR packages
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-outdated",description:"Compare installed versions of tracked packages against their sources and show which ones have an update available.",help:`u-outdated 1.4.1

Compare installed versions of tracked packages against their sources and
show which ones have an update available.

Usage: u-outdated [OPTIONS]

Options:
  --native       Check only native packages
  --nix          Check only Nix packages
  --aur          Check only AUR packages
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-info",description:"Show detailed information about a package tracked by u-install.",help:`u-info 1.4.1

Show detailed information about a package tracked by u-install.

Usage: u-info [OPTIONS] <PACKAGE...>

Options:
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-diff",description:"Compare two .u snapshot files to see differences in packages and versions.",help:`u-diff 1.4.1

Compare two .u snapshot files to see differences in packages and versions.

Usage: u-diff [OPTIONS] <FILE1.u> <FILE2.u>

Options:
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-sync",description:"Synchronize the current machine's packages with a .u snapshot file. Installs missing packages and optionally removes extras.",help:`u-sync 1.4.1

Synchronize the current machine's packages with a .u snapshot file.
Installs missing packages and optionally removes extras.

Usage: u-sync [OPTIONS] <FILE.u>

Options:
  -y, --yes      Assume yes to all prompts
  --dry-run      Show what would be synced without making changes
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-history",description:"Show the journal of u-install actions (installs, removals, upgrades).",help:`u-history 1.4.1

Show the journal of u-install actions (installs, removals, upgrades).

Usage: u-history [OPTIONS] [N]

Arguments:
  N              Show the last N entries (default: 20)

Options:
  -a, --all      Show the full journal
  -p, --pkg PKG  Show only entries for PKG
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-clean",description:"Reclaim disk space: clear the search cache, cached AUR build directories, old Nix generations and native orphan packages. Shows what would be freed before touching anything.",help:`u-clean 1.4.1

Reclaim disk space: clear the search cache, cached AUR build directories,
old Nix generations and native orphan packages. Shows what would be freed
before touching anything.

Usage: u-clean [OPTIONS]

Options:
  --dry-run      Show what would be cleaned without making changes
  -y, --yes      Assume yes to all prompts
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-stats",description:"Show statistics about packages tracked by u-install.",help:`u-stats 1.4.1

Show statistics about packages tracked by u-install.

Usage: u-stats [OPTIONS]

Options:
  -V, --version  Show version information
  -h, --help  Show this help message`},{name:"u-doctor",description:"Diagnose the environment: dependencies, sources, config and conflicts.",help:`u-doctor 1.4.1

Diagnose the environment: dependencies, sources, config and conflicts.

Usage: u-doctor [OPTIONS]

Options:
  --fix          Interactive first-run wizard: create/tune the config,
                 check PATH and offer a starter profile
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-export",description:"Export your u-install setup (installer config + tracked packages) to a portable .u file. Copy that file to another machine and run `u-import` to reproduce the same configuration and packages.",help:`u-export 1.4.1

Export your u-install setup (installer config + tracked packages) to a
portable .u file. Copy that file to another machine and run \`u-import\`
to reproduce the same configuration and packages.

Usage: u-export [OPTIONS] [FILE]

Arguments:
  FILE           Output file (default: configuration.u)

Options:
  -f, --force    Overwrite FILE without asking
  -V, --version  Show version information
  -h, --help     Show this help message`},{name:"u-import",description:"Apply a .u file produced by `u-export`: restore the installer configuration and (re)install every package it lists. Use it to bring a fresh machine to the same state as an existing one.",help:`u-import 1.4.1

Apply a .u file produced by \`u-export\`: restore the installer configuration
and (re)install every package it lists. Use it to bring a fresh machine to the
same state as an existing one.

Usage: u-import [OPTIONS] <FILE>

Options:
  --config-only    Apply only the installer configuration
  --packages-only  Install only the packages
  --latest         Ignore pinned versions; install the latest available
  -y, --yes        Assume yes to all prompts
  -V, --version    Show version information
  -h, --help       Show this help message`},{name:"u-help",description:"Top-level entry point for the u-install toolkit: lists every u-* command. Run any command with --help for its own options.",help:`u-help 1.4.1

Top-level entry point for the u-install toolkit: lists every u-* command.
Run any command with --help for its own options.

Usage: u-help [OPTIONS]

Options:
  -V, --version  Show version information
  -h, --help     Show this help message`}],c={version:p,commands:u},d=localStorage.getItem("u-install-theme"),m=d||(matchMedia("(prefers-color-scheme: dark)").matches?"dark":"light");document.documentElement.dataset.theme=m;window.toggleTheme=()=>{const e=document.documentElement.dataset.theme==="dark"?"light":"dark";document.documentElement.dataset.theme=e,localStorage.setItem("u-install-theme",e)};const g=[["","Home"],["install.html","Install"],["commands.html","Commands"],["u-format.html",".u Format"],["config.html","Config"]],r=document.getElementById("nav");if(r){const e=location.pathname.split("/").pop()||"index.html";r.outerHTML=`
  <nav class="navbar">
    <div class="container">
      <a class="nav-brand" href="./index.html">
        <img src="./u-install-logo.svg" alt="u-install logo">
        <span><span class="u">u</span>-install</span>
        <span class="nav-version">v${c.version}</span>
      </a>
      <div class="nav-links">
        ${g.map(([t,a])=>{const o=t||"index.html";return`<a href="./${o}"${e===o?' class="active"':""}>${a}</a>`}).join("")}
        <button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme" aria-label="Toggle theme">
          <svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4m11.4-11.4 1.4-1.4"/></svg>
          <svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>
        </button>
        <a class="gh" href="https://github.com/runvoid/u-install" target="_blank" rel="noopener" title="GitHub">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .5A11.5 11.5 0 0 0 .5 12a11.5 11.5 0 0 0 7.9 10.9c.6.1.8-.2.8-.5v-2c-3.2.7-3.9-1.4-3.9-1.4-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.7 1.3 3.4 1 .1-.8.4-1.3.7-1.6-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.4-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.2 1.2a11 11 0 0 1 5.8 0C16.7 4.9 17.7 5.2 17.7 5.2c.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.6.8.5A11.5 11.5 0 0 0 23.5 12 11.5 11.5 0 0 0 12 .5z"/></svg>
        </a>
      </div>
    </div>
  </nav>`}const l=document.getElementById("footer");l&&(l.outerHTML=`
  <footer class="footer">
    <div class="container">
      <span>MIT License · built by <a href="https://github.com/runvoid" target="_blank" rel="noopener">runvoid</a> with <span class="heart">♥</span> and pure Bash</span>
      <span>
        <a href="https://github.com/runvoid/u-install" target="_blank" rel="noopener">GitHub</a> ·
        <a href="https://github.com/runvoid/u-install/releases" target="_blank" rel="noopener">Releases</a> ·
        v${c.version}
      </span>
    </div>
  </footer>`);window.copyText=async(e,t)=>{try{await navigator.clipboard.writeText(t)}catch{const o=document.createElement("textarea");o.value=t,document.body.appendChild(o),o.select(),document.execCommand("copy"),o.remove()}const a=e.textContent;e.textContent="copied!",e.classList.add("copied"),setTimeout(()=>{e.textContent=a,e.classList.remove("copied")},1200)};document.querySelectorAll(".code-block").forEach(e=>{if(e.dataset.skipCopy!==void 0)return;const t=e.querySelector("pre");if(!t)return;const a=document.createElement("button");a.className="copy-btn",a.type="button",a.textContent="copy",a.addEventListener("click",()=>window.copyText(a,t.innerText)),e.appendChild(a)});const h=new IntersectionObserver(e=>{e.forEach(t=>{t.isIntersecting&&(t.target.classList.add("visible"),h.unobserve(t.target))})},{threshold:.08});document.querySelectorAll(".reveal").forEach(e=>h.observe(e));export{c};
