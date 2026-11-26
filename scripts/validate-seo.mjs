import { readFile, readdir } from 'node:fs/promises'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('../dist/', import.meta.url))
const errors = []
const auditWarnings = []
const read = async (path) => readFile(join(root,path),'utf8')
async function walk(dir) {
  const all = await readdir(dir,{withFileTypes:true})
  const results = await Promise.all(all.map(async e => e.isDirectory()?walk(join(dir,e.name)):[join(dir,e.name)]))
  return results.flat()
}
const htmlFiles = (await walk(root)).filter(x => x.endsWith('index.html'))
const indexable = new Map()
const titleOwners = new Map()
const descriptionOwners = new Map()
const pendingLinks = []
const head = (html) => html.split('</head>')[0] ?? ''
for (const file of htmlFiles) {
  const rel = relative(root,file).split(sep).join('/')
  const path = rel === 'index.html' ? '/' : '/'+rel.replace(/index\.html$/,'')
  const html = await readFile(file,'utf8')
  const h = head(html)
  const hasNoIndex = /<meta\s+name="robots"\s+content="[^"]*noindex/i.test(h)
  if (hasNoIndex) continue
  const canonical = h.match(/<link\s+rel="canonical"\s+href="([^"]+)"/)?.[1]
  const expected = 'https://camvella.com'+path
  if (canonical !== expected) errors.push(`${path}: canonical is ${canonical||'missing'}, expected ${expected}`)
  if (!/<meta\s+name="description"\s+content="[^"]{40,}"/i.test(h)) errors.push(`${path}: missing short or empty description`)
  if (!/<title>[^<]{12,}<\/title>/i.test(h)) errors.push(`${path}: missing title`)
  if (!/<meta\s+property="og:url"/i.test(h)) errors.push(`${path}: missing social URL`)
  if (h.includes('\\n  <meta')) errors.push(`${path}: escaped newline appears in head markup`)
  if (!/<script\s+type="application\/ld\+json"/i.test(h)) errors.push(`${path}: missing structured data`)
  const pageTitle = h.match(/<title>([^<]+)<\/title>/i)?.[1]?.trim()
  const pageDescription = h.match(/<meta\s+name="description"\s+content="([^"]+)"/i)?.[1]?.trim()
  if (pageTitle) {
    if (titleOwners.has(pageTitle)) auditWarnings.push(`${path}: duplicate title with ${titleOwners.get(pageTitle)}`)
    else titleOwners.set(pageTitle,path)
  }
  if (pageDescription) {
    if (descriptionOwners.has(pageDescription)) auditWarnings.push(`${path}: duplicate meta description with ${descriptionOwners.get(pageDescription)}`)
    else descriptionOwners.set(pageDescription,path)
  }
  for (const link of html.matchAll(/<a\b[^>]*\bhref="([^"]+)"/gi)) pendingLinks.push({from:path,href:link[1]})
  indexable.set(expected,path)
}
// Every internal navigation link must resolve to an actual generated page or
// published public asset. Link checking is independent of whether a target is noindex.
const generatedFiles = new Set((await walk(root)).map(file => relative(root,file).split(sep).join('/')))
for (const {from,href} of pendingLinks) {
  if (!href.startsWith('/') || href.startsWith('//')) continue
  const pathname = href.split(/[?#]/,1)[0]
  if (!pathname) continue
  const dest = decodeURIComponent(pathname).replace(/^\/+/, '')
  const candidate = dest.endsWith('/') ? dest + 'index.html' : dest + '/index.html'
  if (!generatedFiles.has(candidate) && !generatedFiles.has(dest)) {
    auditWarnings.push(`${from}: broken internal link ${href}`)
  }
}
const sitemap = await read('sitemap.xml')
const urls = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(x=>x[1])
const urlSet = new Set(urls)
const lastmodEntries = [...sitemap.matchAll(/<url>\s*<loc>([^<]+)<\/loc>([\s\S]*?)<\/url>/g)]
const homeEntry = lastmodEntries.find(x => x[1] === 'https://camvella.com/')
if (!homeEntry || !/<lastmod>\d{4}-\d{2}-\d{2}<\/lastmod>/.test(homeEntry[2])) errors.push('homepage sitemap lastmod missing or invalid')
for(const [,url,body] of lastmodEntries){
  const value = body.match(/<lastmod>([^<]+)<\/lastmod>/)?.[1]
  if(value && !/^\d{4}-\d{2}-\d{2}$/.test(value)) errors.push(`invalid sitemap lastmod: ${url}`)
}
if (urlSet.size !== urls.length) errors.push('duplicate URLs in sitemap')
if (urls.length < 75) errors.push(`only ${urls.length} URLs in sitemap: expected site sections and state pages`)
for(const u of urls){
  if(!indexable.has(u)) errors.push(`sitemap includes absent or noindex URL: ${u}`)
}
for(const u of indexable.keys()){
  if(!urlSet.has(u)) errors.push(`indexable page missing from sitemap: ${u}`)
}
for(const url of ['/','/blog/','/guides/','/pricing/','/demo/','/locations/','/solutions/hoa-management-software/']){
  if(!urlSet.has('https://camvella.com'+url))errors.push(`required hub missing in sitemap: ${url}`)
}
const amenitiesPage = await read('features/amenity-reservations/index.html')
if (!amenitiesPage.includes('HOA Amenity Reservations')) errors.push('amenity reservation SEO landing page missing title/content')
if (!urlSet.has('https://camvella.com/features/amenity-reservations/')) errors.push('amenity reservation landing page missing from sitemap')
const productPage = await read('product/index.html')
if (!productPage.includes('href="/features/amenity-reservations"')) errors.push('product page missing amenity feature link')
const robots = await read('robots.txt')
if(!robots.includes('Sitemap: https://camvella.com/sitemap.xml'))errors.push('robots.txt sitemap URL missing')
if(/Disallow:\s*\//m.test(robots) && /Disallow:\s*\/\s*$/m.test(robots))errors.push('robots.txt disallows whole site')
// Buyer journey guardrails: prevent regressions that bury the demo or disconnect comparisons.
for(const [route,links] of [
  ['pricing/index.html',['/compare/','/demo','/guides/hoa-software-pricing-guide/']],
  ['solutions/management-companies/index.html',['/demo','/guides/hoa-software-buyers-guide/','/guides/hoa-software-implementation-checklist/']],
]){
  const html = await read(route)
  for(const url of links) if(!html.includes('href="'+url+'"'))errors.push(`${route}: missing buyer path ${url}`)
}
const demoPage = await read('demo/index.html')
if((demoPage.match(/<main\b/g)||[]).length > 1)errors.push('demo page has nested main landmarks')
if(!demoPage.includes('id="camvella-scheduler"'))errors.push('demo scheduler missing')
const homepage = await read('index.html')
if(!homepage.includes('G-H1ZPCP2EE9') || !homepage.includes('y62zna7yna'))errors.push('GA4/Clarity bootstrap missing')
const criticalLinks=['/blog','/guides','/demo','/pricing','/locations']
for(const url of criticalLinks)if(!homepage.includes('href="'+url))errors.push(`homepage missing link to ${url}`)
// New metadata and internal-link checks report issues without changing release
// pass/fail until an actual build has established their baseline.
if (auditWarnings.length) console.warn('Camvella expanded SEO audit warnings:\n' + auditWarnings.slice(0,80).map(x => ' - ' + x).join('\n'))
if(errors.length) {
  console.error('Camvella SEO validation FAILED:\n'+errors.slice(0,60).map(x=>' - '+x).join('\n'))
  console.error(`${errors.length} SEO defects detected across ${htmlFiles.length} HTML files`)
  process.exitCode=1
} else {
  console.log(`Camvella SEO validation PASS: ${urls.length} sitemap URLs, ${indexable.size} indexable HTML routes, canonical, metadata, structured data, analytics, hubs, robots checked.`)
}
