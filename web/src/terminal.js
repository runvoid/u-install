/* Animated hero terminal: types commands, prints colored output, loops. */

const SCENARIO = [
  {
    cmd: 'u-search neovim',
    out: [
      ['out', '  SOURCE     PACKAGE     VERSION     STATUS'],
      ['out', '  ---------- ----------- ----------- ----------'],
      ['ok',   '  native     neovim      0.10.4-8    available'],
      ['out',  '  nix        neovim                  Nix not installed'],
      ['out',  '  aur        neovim                  Arch only'],
    ],
  },
  {
    cmd: 'u-install neovim',
    out: [
      ['out', '  Distribution: debian'],
      ['ok',   '  [##########----------]  50% processing neovim'],
      ['out',  '  Installing \u2019neovim\u2019 via apt...'],
      ['ok',   '  [u-install] Installed via native'],
      ['ok',   '  \u2713 1 installed \u00b7 \u2013 0 skipped \u00b7 \u2717 0 failed'],
    ],
  },
  {
    cmd: 'u-export setup.u',
    out: [
      ['ok',   '  [u-install] Exported configuration and 1 package(s) to setup.u'],
      ['out',  '  [u-install] Integrity: sha256 checksum embedded in [meta]'],
    ],
  },
]

const body = document.getElementById('term-body')
if (body) {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

  const line = (cls, text) => {
    const el = document.createElement('div')
    if (cls) el.className = cls
    el.textContent = text
    body.appendChild(el)
    return el
  }

  const typeCommand = async (text) => {
    const el = line('p', '')
    const caret = document.createElement('span')
    caret.className = 'caret'
    el.appendChild(caret)
    for (const ch of text) {
      caret.insertAdjacentText('beforebegin', ch)
      await sleep(34 + Math.random() * 46)
    }
    await sleep(300)
    caret.remove()
  }

  const run = async () => {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      body.replaceChildren()
      for (const step of SCENARIO) {
        await typeCommand(step.cmd)
        await sleep(220)
        for (const [cls, text] of step.out) {
          line(cls, text)
          await sleep(120)
        }
        await sleep(650)
      }
      line('out', '')
      line('out', '  \u00b7 \u00b7 \u00b7 restoring on another machine: u-import setup.u \u00b7 \u00b7 \u00b7')
      await sleep(2600)
    }
  }

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches
  if (reduced) {
    // No animation: just render the first step statically.
    for (const step of SCENARIO.slice(0, 2)) {
      line('p', step.cmd)
      for (const [cls, text] of step.out) line(cls, text)
    }
  } else {
    run()
  }
}
