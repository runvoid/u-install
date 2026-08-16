import './style.css'
import commandsData from './data/commands.json'

/* ---------------------------------------------------------------- theme --- */

const saved = localStorage.getItem('u-install-theme')
const theme = saved || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
document.documentElement.dataset.theme = theme

window.toggleTheme = () => {
  const next = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'
  document.documentElement.dataset.theme = next
  localStorage.setItem('u-install-theme', next)
}

/* ------------------------------------------------------------------- nav --- */

const pages = [
  ['', 'Home'],
  ['install.html', 'Install'],
  ['commands.html', 'Commands'],
  ['u-format.html', '.u Format'],
  ['config.html', 'Config'],
]

const nav = document.getElementById('nav')
if (nav) {
  const here = location.pathname.split('/').pop() || 'index.html'
  nav.outerHTML = `
  <nav class="navbar">
    <div class="container">
      <a class="nav-brand" href="./index.html">
        <img src="./u-install-logo.svg" alt="u-install logo">
        <span><span class="u">u</span>-install</span>
        <span class="nav-version">v${commandsData.version}</span>
      </a>
      <div class="nav-links">
        ${pages
          .map(([file, label]) => {
            const target = file || 'index.html'
            const active = here === target ? ' class="active"' : ''
            return `<a href="./${target}"${active}>${label}</a>`
          })
          .join('')}
        <button class="theme-toggle" onclick="toggleTheme()" title="Toggle theme" aria-label="Toggle theme">
          <svg class="sun" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4m11.4-11.4 1.4-1.4"/></svg>
          <svg class="moon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z"/></svg>
        </button>
        <a class="gh" href="https://github.com/runvoid/u-install" target="_blank" rel="noopener" title="GitHub">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .5A11.5 11.5 0 0 0 .5 12a11.5 11.5 0 0 0 7.9 10.9c.6.1.8-.2.8-.5v-2c-3.2.7-3.9-1.4-3.9-1.4-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1 1.8 2.7 1.3 3.4 1 .1-.8.4-1.3.7-1.6-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.4-2.3 1.2-3.1-.1-.3-.5-1.5.1-3.1 0 0 1-.3 3.2 1.2a11 11 0 0 1 5.8 0C16.7 4.9 17.7 5.2 17.7 5.2c.6 1.6.2 2.8.1 3.1.8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.6.8.5A11.5 11.5 0 0 0 23.5 12 11.5 11.5 0 0 0 12 .5z"/></svg>
        </a>
      </div>
    </div>
  </nav>`
}

/* ---------------------------------------------------------------- footer --- */

const footer = document.getElementById('footer')
if (footer) {
  footer.outerHTML = `
  <footer class="footer">
    <div class="container">
      <span>MIT License · built by <a href="https://github.com/runvoid" target="_blank" rel="noopener">runvoid</a> with <span class="heart">♥</span> and pure Bash</span>
      <span>
        <a href="https://github.com/runvoid/u-install" target="_blank" rel="noopener">GitHub</a> ·
        <a href="https://github.com/runvoid/u-install/releases" target="_blank" rel="noopener">Releases</a> ·
        v${commandsData.version}
      </span>
    </div>
  </footer>`
}

/* ------------------------------------------------------------------ copy --- */

window.copyText = async (btn, text) => {
  try {
    await navigator.clipboard.writeText(text)
  } catch {
    const ta = document.createElement('textarea')
    ta.value = text
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    ta.remove()
  }
  const prev = btn.textContent
  btn.textContent = 'copied!'
  btn.classList.add('copied')
  setTimeout(() => {
    btn.textContent = prev
    btn.classList.remove('copied')
  }, 1200)
}

document.querySelectorAll('.code-block').forEach((block) => {
  if (block.dataset.skipCopy !== undefined) return
  const pre = block.querySelector('pre')
  if (!pre) return
  const btn = document.createElement('button')
  btn.className = 'copy-btn'
  btn.type = 'button'
  btn.textContent = 'copy'
  btn.addEventListener('click', () => window.copyText(btn, pre.innerText))
  block.appendChild(btn)
})

/* --------------------------------------------------------------- reveal --- */

const io = new IntersectionObserver(
  (entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        e.target.classList.add('visible')
        io.unobserve(e.target)
      }
    })
  },
  { threshold: 0.08 },
)
document.querySelectorAll('.reveal').forEach((el) => io.observe(el))
