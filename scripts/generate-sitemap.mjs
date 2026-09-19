// Favicon parity gate: match working BocaSync 96x96 PNG browser contract
import { readFile, readdir, writeFile } from 'node:fs/promises'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const dist = new URL('../dist/', import.meta.url)
const distPath = fileURLToPath(dist)
const site = 'https://camvella.com'
const excluded = new Set([
  '/404/',
  '/demo/thank-you/',
  '/solutions/florida-hoa-management-software/',
  '/solutions/texas-hoa-management-software/',
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


// Camvella SEO build gate: keep the established resource hub and new authority guides connected.
if (!paths.includes('/blog/')) throw new Error('Camvella SEO build gate: /blog/ resource hub was not generated')
if (!paths.includes('/guides/')) throw new Error('Camvella SEO build gate: /guides/ authority hub was not generated')
if (!paths.some((path) => path.startsWith('/guides/') && path !== '/guides/')) throw new Error('Camvella SEO build gate: no guide detail pages were generated')
const homepage = await readFile(new URL('index.html', dist), 'utf8')
if (!homepage.includes('rel="icon" type="image/png" sizes="96x96" href="/favicon.png"')) throw new Error('Camvella favicon build gate: homepage is missing the stable Google-supported PNG favicon')
const manifest = await readFile(new URL('manifest.json', dist), 'utf8')
if (!manifest.includes('"src": "/favicon.png"')) throw new Error('Camvella favicon build gate: manifest is missing the stable Google-supported PNG favicon')
if (!homepage.includes('href="/blog"')) throw new Error('Camvella SEO build gate: homepage is missing the Resources → /blog crawl path')
const resourceHub = await readFile(new URL('blog/index.html', dist), 'utf8')
if (!resourceHub.includes('href="/guides/')) throw new Error('Camvella SEO build gate: /blog/ does not link into the /guides/ authority cluster')
const homeAndHub = homepage + resourceHub
for (const alias of ['/solutions/florida-hoa-management-software', '/solutions/texas-hoa-management-software']) {
  if (homeAndHub.includes('href="' + alias)) throw new Error('Camvella SEO build gate: indexable hubs must not link to noindex regional alias ' + alias)
}
const redirects = await readFile(new URL('../public/_redirects', import.meta.url), 'utf8')
for (const rule of [
  '/solutions/florida-hoa-management-software /locations/florida/ 301',
  '/solutions/florida-hoa-management-software/ /locations/florida/ 301',
  '/solutions/texas-hoa-management-software /locations/texas/ 301',
  '/solutions/texas-hoa-management-software/ /locations/texas/ 301',
]) {
  if (!redirects.includes(rule)) throw new Error('Camvella SEO build gate: missing Cloudflare regional redirect rule ' + rule)
}

const lastmod = new Date().toISOString().slice(0, 10)

const entries = paths.map((path) => {
  const priority =
    path === '/' ? '1.0'
    : path === '/pricing/' || path === '/demo/' ? '0.9'
    : path.startsWith('/features/') || path.startsWith('/solutions/') ? '0.8'
    : path.startsWith('/compare/') ? '0.75'
    : path === '/security/' ? '0.6'
    : path === '/privacy/' || path === '/terms/' ? '0.3'
    : '0.7'
  return [
    '  <url>',
    `    <loc>${site}${path === '/' ? '/' : path}</loc>`,
    `    <lastmod>${lastmod}</lastmod>`,
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
