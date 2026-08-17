import { defineConfig } from 'astro/config'
import react from '@astrojs/react'

// Sitemap generated manually at /public/sitemap.xml for Phase 1
// Will integrate @astrojs/sitemap once version compatibility is resolved

export default defineConfig({
  site: 'https://camvella.com',
  integrations: [react()],
  compressHTML: true,
  build: {
    inlineStylesheets: 'auto',
  },
})
