import { defineConfig } from 'astro/config'
import react from '@astrojs/react'
import sitemap from '@astrojs/sitemap'

export default defineConfig({
  site: 'https://camvella.com',
  integrations: [
    react(),
    sitemap({
      filter: (page) =>
        !page.includes('/demo/thank-you') &&
        !page.includes('/404'),
    }),
  ],
  compressHTML: true,
  build: {
    inlineStylesheets: 'auto',
  },
})
