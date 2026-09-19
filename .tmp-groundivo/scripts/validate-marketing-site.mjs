import fs from 'node:fs/promises'
import path from 'node:path'

const ROOT='marketing-site'
const requiredRoutes=[
  '/',
  '/landscaping-crm/',
  '/lawn-care-software/',
  '/landscaping-scheduling-software/',
  '/landscaping-estimating-software/',
  '/route-planning-software/',
  '/landscaping-invoicing-software/',
  '/jobber-alternative-for-landscaping/',
  '/aspire-alternative/',
  '/lmn-alternative/',
  '/florida-landscaping-software/',
  '/texas-landscaping-software/',
  '/pest-control-crm/',
  '/irrigation-business-software/',
  '/tree-service-crm/',
  '/landscaping-software-small-business/',
  '/locations/',
  '/pricing/',
  '/security/'
]

const buyerReadinessRoutes=[
  '/',
  '/landscaping-crm/',
  '/lawn-care-software/',
  '/landscaping-scheduling-software/',
  '/landscaping-estimating-software/',
  '/route-planning-software/',
  '/landscaping-invoicing-software/',
  '/jobber-alternative-for-landscaping/',
  '/aspire-alternative/',
  '/lmn-alternative/',
  '/florida-landscaping-software/',
  '/texas-landscaping-software/',
  '/pest-control-crm/',
  '/irrigation-business-software/',
  '/tree-service-crm/',
  '/landscaping-software-small-business/',
  '/pricing/',
  '/security/'
]
const unfinished=/\bcoming soon\b|\bbeing built\b|\bactively being developed\b|\blorem ipsum\b|\bTODO\b/i

const routeFile=route=>route==='/'?path.join(ROOT,'index.html'):path.join(ROOT,route.slice(1),'index.html')
const errors=[]
const styles=await fs.readFile(path.join(ROOT,'styles.css'),'utf8')
for(const token of [
  'GroundIVO CRM palette alignment',
  '--panel:#15231d',
  '--green:#9bdc34',
  '--teal:#21c9b7',
  '.section,.crm-proof{background:#0e1511',
  '.footer{background:#101a16'
]) if(!styles.includes(token)) errors.push(`shared marketing palette missing ${token}`)
const buildScript=await fs.readFile(path.join(ROOT,'build.mjs'),'utf8')
if(!/const ga4Id = 'G-BBHLF92295'/.test(buildScript)) errors.push('marketing build missing verified GroundIVO GA4 Measurement ID')
if(!/const clarityId = 'ygv0xf8tea'/.test(buildScript)) errors.push('marketing build missing verified GroundIVO Clarity project ID')
if(!/analytics\.js/.test(buildScript)) errors.push('marketing build missing analytics loader injection')
if(!/\/favicon\.svg\?v=20260918/.test(buildScript)) errors.push('marketing build missing versioned GroundIVO SVG favicon injection')
try{await fs.access(path.join(ROOT,'favicon.svg'))}catch{errors.push('favicon.svg missing approved GroundIVO favicon')}

for(const route of requiredRoutes){
  const file=routeFile(route)
  let html=''
  try{html=await fs.readFile(file,'utf8')}catch{errors.push(`missing route file: ${route} -> ${file}`);continue}
  const expectedCanonical=`https://groundivo.com${route}`
  if(!/<meta\s+name=["']viewport["']/i.test(html)) errors.push(`${route}: missing viewport meta`)
  if(route==='/' && !/rel=["']icon["'][^>]+type=["']image\/svg\+xml["'][^>]+href=["']\/favicon\.svg\?v=20260918["']/i.test(html)) errors.push(`${route}: homepage missing versioned GroundIVO favicon declaration`)
  if(!/<title>[^<]{10,}<\/title>/i.test(html)) errors.push(`${route}: missing/weak title`)
  if(!/<meta\s+name=["']description["'][^>]+content=["'][^"']{50,}["']/i.test(html) && !/<meta\s+content=["'][^"']{50,}["'][^>]+name=["']description["']/i.test(html)) errors.push(`${route}: missing/weak meta description`)
  if(!html.includes(`href="${expectedCanonical}"`) && !html.includes(`href='${expectedCanonical}'`)) errors.push(`${route}: canonical mismatch; expected ${expectedCanonical}`)
  if(!/application\/ld\+json/i.test(html)) errors.push(`${route}: missing JSON-LD schema`)
  if(!/GroundIVO/.test(html)) errors.push(`${route}: GroundIVO brand missing`)
  if(/\bGroundivo\b/.test(html)) errors.push(`${route}: stale Groundivo casing`)
  if(/PHL\s*Land\s*Care|phllandcare\.com|gmblbltckwipghqutkhw/i.test(html)) errors.push(`${route}: PHL contamination`)
  if(buyerReadinessRoutes.includes(route) && unfinished.test(html)) errors.push(`${route}: unfinished buyer-facing language`)
  if(buyerReadinessRoutes.includes(route) && !/taxrescrm\.app\/book\?product=groundivo|Book a demo|Book demo/i.test(html)) errors.push(`${route}: missing direct demo CTA`)
  if(route==='/pricing/' && !/\$149/.test(html)) errors.push(`${route}: Starter price missing`)
  if(route==='/pricing/' && !/\$299/.test(html)) errors.push(`${route}: Growth price missing`)
  if(route==='/pricing/' && !/\$499/.test(html)) errors.push(`${route}: Scale price missing`)
  if(route==='/security/' && !/Row Level Security|tenant isolation/i.test(html)) errors.push(`${route}: tenant isolation explanation missing`)
  if(route==='/' && !html.includes('linear-gradient(180deg,#101a16 0%,#0e1511 100%)')) errors.push(`${route}: homepage hero is not using approved GroundIVO palette`)
}

const sitemap=await fs.readFile(path.join(ROOT,'sitemap.xml'),'utf8')
for(const route of requiredRoutes){
  const loc=`<loc>https://groundivo.com${route}</loc>`
  if(!sitemap.includes(loc)) errors.push(`sitemap missing ${route}`)
}
const sitemapRoutes=[...sitemap.matchAll(/<loc>https:\/\/groundivo\.com([^<]*)<\/loc>/g)].map(m=>m[1]||'/')
for(const route of sitemapRoutes){
  const normalized=route||'/'
  try{await fs.access(routeFile(normalized))}catch{errors.push(`sitemap points to missing route: ${normalized}`)}
}

const genericStateUrls=sitemapRoutes.filter(route=>/^\/locations\/[^/]+\/$/.test(route))
if(genericStateUrls.length < 48) errors.push(`expected at least 48 generic state pages in sitemap, found ${genericStateUrls.length}`)
let headers=''
try{headers=await fs.readFile(path.join(ROOT,'_headers'),'utf8')}catch{}
if(/X-Robots-Tag:\s*noindex/i.test(headers)) errors.push('_headers must not noindex public state pages')
for(const route of genericStateUrls){
  const html=await fs.readFile(routeFile(route),'utf8')
  if(/<meta\s+name=["']robots["'][^>]+noindex/i.test(html)) errors.push(`${route}: public state page must not be noindex`)
}

const robots=await fs.readFile(path.join(ROOT,'robots.txt'),'utf8')
if(!/User-agent:\s*\*/i.test(robots)) errors.push('robots.txt missing wildcard user-agent')
if(!/Sitemap:\s*https:\/\/groundivo\.com\/sitemap\.xml/i.test(robots)) errors.push('robots.txt missing canonical sitemap URL')


let llms=''
try{llms=await fs.readFile(path.join(ROOT,'llms.txt'),'utf8')}catch{errors.push('llms.txt missing AI discovery manifest')}
if(llms && !/^# GroundIVO/m.test(llms)) errors.push('llms.txt missing GroundIVO heading')
if(llms && !/https:\/\/groundivo\.com\//.test(llms)) errors.push('llms.txt missing canonical GroundIVO URL')
if(llms && !/landscaping CRM software/i.test(llms)) errors.push('llms.txt missing core product category')

if(errors.length){
  console.error('GroundIVO marketing audit FAILED')
  for(const e of errors) console.error(`- ${e}`)
  process.exit(1)
}
console.log(`GroundIVO marketing audit passed: ${requiredRoutes.length} required routes + buyer-readiness + sitemap + robots + state indexing + llms.txt contract.`)
