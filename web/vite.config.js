import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'

const root = dirname(fileURLToPath(import.meta.url))

// Multi-page site; the build output goes straight into ../docs which is what
// GitHub Pages serves. Relative base keeps it working at any sub-path.
export default defineConfig({
  base: './',
  build: {
    outDir: '../docs',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        main: resolve(root, 'index.html'),
        commands: resolve(root, 'commands.html'),
        uformat: resolve(root, 'u-format.html'),
        config: resolve(root, 'config.html'),
        install: resolve(root, 'install.html'),
      },
    },
  },
})
