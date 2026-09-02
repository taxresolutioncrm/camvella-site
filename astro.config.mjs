import { defineConfig } from 'astro/config'
import react from '@astrojs/react'
import sitemap from '@astrojs/sitemap'

const noIndexPaths = [
  '/demo/thank-you',
  '/compare/camvella-vs-appfolio',
  '/compare/camvella-vs-buildium',
  '/compare/camvella-vs-enumerate',
  '/compare/camvella-vs-vantaca',
  '/compare/cinc-alternatives',
  '/compare/vantaca-alternatives',
]

export default defineConfig({
  site: 'https://camvella.com',
  integrations: [
    react(),
    sitemap({
      filter: (page) => {
        const pathname = new URL(page).pathname.replace(/\/$/, '') || '/'
        return !noIndexPaths.includes(pathname)
      },
      changefreq: 'weekly',
      priority: 0.7,
    }),
  ],
  compressHTML: true,
  build: {
    inlineStylesheets: 'auto',
  },
})
