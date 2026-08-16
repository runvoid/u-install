import commandsData from './data/commands.json'

/* Command reference: groups, live filter, cards rendered from the
   auto-generated commands.json (built by tools/gen-docs.sh from real
   --help output, so the page can never go stale). */

const GROUPS = [
  ['Core', ['u-install', 'u-uninstall', 'u-update', 'u-upgrade', 'u-search']],
  ['Insight', ['u-outdated', 'u-peek', 'u-info', 'u-list', 'u-stats', 'u-history']],
  ['Snapshots', ['u-export', 'u-import', 'u-diff', 'u-sync']],
  ['System', ['u-doctor', 'u-clean', 'u-help']],
]

const groupOf = (name) => {
  for (const [title, names] of GROUPS) if (names.includes(name)) return title
  return 'Other'
}

const escapeHtml = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

const root = document.getElementById('commands-root')
const search = document.getElementById('cmd-search')
const count = document.getElementById('cmd-count')

const render = (filter) => {
  const f = filter.trim().toLowerCase()
  const items = commandsData.commands.filter(
    (c) =>
      !f ||
      c.name.toLowerCase().includes(f) ||
      c.description.toLowerCase().includes(f) ||
      c.help.toLowerCase().includes(f),
  )
  count.textContent = `${items.length}/${commandsData.commands.length}`

  if (items.length === 0) {
    root.innerHTML = `<div class="empty-note">Nothing matches \u201c${escapeHtml(filter)}\u201d.</div>`
    return
  }

  const byGroup = new Map()
  for (const c of items) {
    const g = groupOf(c.name)
    if (!byGroup.has(g)) byGroup.set(g, [])
    byGroup.get(g).push(c)
  }

  let html = ''
  for (const [title, names] of GROUPS) {
    if (!byGroup.has(title)) continue
    html += `<div class="cmd-group-title">${title}</div>`
    for (const c of byGroup.get(title)) {
      html += `
      <div class="cmd-card reveal visible">
        <div class="head">
          <span class="name">${c.name}</span>
          <span class="tag">${title}</span>
        </div>
        <p class="desc">${escapeHtml(c.description)}</p>
        <div class="code-block"><pre>${escapeHtml(c.help)}</pre></div>
      </div>`
    }
  }
  root.innerHTML = html
}

if (root) {
  render('')
  search.addEventListener('input', () => render(search.value))
}
