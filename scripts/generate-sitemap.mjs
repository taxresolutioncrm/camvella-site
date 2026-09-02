import { readdir, writeFile } from 'node:fs/promises'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const dist = new URL('../dist/', import.meta.url)
const distPath = fileURLToPath(dist)
const site = 'https://camvella.com'
const excluded = new Set([
  '/404/',
  '/demo/thank-you/',
  '/compare/camvella-vs-appfolio/',
  '/compare/camvella-vs-buildium/',
  '/compare/camvella-vs-enumerate/',
  '/compare/camvella-vs-vantaca/',
  '/compare/cinc-alternatives/',
  '/compare/vantaca-alternatives/',
])

async function htmlFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true })
  const nested = await Promise.all(entries.map((entry) => {
    const path = join(directory, entry.name)
    return entry.isDirectory() ? htmlFiles(path) : [path]
  }))
  return nested.flat()
}

const files = await htmlFiles(distPath)
const paths = files
  .filter((file) => file.endsWith(`${sep}index.html`) || file.endsWith('/index.html'))
  .map((file) => {
    const local = relative(distPath, file).split(sep).join('/')
    return local === 'index.html' ? '/' : `/${local.replace(/index\.html$/, '')}`
  })
  .filter((path) => !excluded.has(path))
  .sort()

const today = new Date().toISOString().slice(0, 10)
const entries = paths.map((path) => {
  const priority = path === '/' ? '1.0' : path === '/pricing/' || path === '/demo/' ? '0.9' : '0.7'
  return [
    '  <url>',
    `    <loc>${site}${path === '/' ? '/' : path}</loc>`,
    `    <lastmod>${today}</lastmod>`,
    '    <changefreq>weekly</changefreq>',
    `    <priority>${priority}</priority>`,
    '  </url>',
  ].join('\n')
})

const xml = [
  '<?xml version="1.0" encoding="UTF-8"?>',
  '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
  ...entries,
  '</urlset>',
  '',
].join('\n')

await writeFile(new URL('sitemap.xml', dist), xml, 'utf8')
console.log(`Generated sitemap.xml with ${paths.length} indexable URLs`)
