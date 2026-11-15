import { readFile, readdir } from 'node:fs/promises'
import { join, relative, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = fileURLToPath(new URL('../dist/', import.meta.url))
const errors = []
const read = async (path) => readFile(join(root,path),'utf8')
async function walk(dir) {
  const all = await readdir(dir,{withFileTypes:true})
  const results = await Promise.all(all.map(async e => e.isDirectory()?walk(join(dir,e.name)):[join(dir,e.name)]))
  return results.flat()
}
const htmlFiles = (await walk(root)).filter(x => x.endsWith('index.html'))
const indexable = new Map()
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
  indexable.set(expected,path)
}
const sitemap = await read('sitemap.xml')
const urls = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(x=>x[1])
const urlSet = new Set(urls)
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
const robots = await read('robots.txt')
if(!robots.includes('Sitemap: https://camvella.com/sitemap.xml'))errors.push('robots.txt sitemap URL missing')
if(/Disallow:\s*\//m.test(robots) && /Disallow:\s*\/\s*$/m.test(robots))errors.push('robots.txt disallows whole site')
const homepage = await read('index.html')
if(!homepage.includes('G-H1ZPCP2EE9') || !homepage.includes('y62zna7yna'))errors.push('GA4/Clarity bootstrap missing')
const criticalLinks=['/blog','/guides','/demo','/pricing','/locations']
for(const url of criticalLinks)if(!homepage.includes('href="'+url))errors.push(`homepage missing link to ${url}`)
if(errors.length) {
  console.error('Camvella SEO validation FAILED:\n'+errors.slice(0,60).map(x=>' - '+x).join('\n'))
  console.error(`${errors.length} SEO defects detected across ${htmlFiles.length} HTML files`)
  process.exitCode=1
} else {
  console.log(`Camvella SEO validation PASS: ${urls.length} sitemap URLs, ${indexable.size} indexable HTML routes, canonical, metadata, structured data, analytics, hubs, robots checked.`)
}
