import { defineConfig } from 'astro/config'
import react from '@astrojs/react'

export default defineConfig({
  site: 'https://camvella.com',
  integrations: [react()],
  compressHTML: true,
  build: {
    inlineStylesheets: 'auto',
  },
})
