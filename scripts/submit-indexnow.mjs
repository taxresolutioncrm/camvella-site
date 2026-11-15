// Notify IndexNow participating search engines only for website content changed
// in this production commit. No Google Indexing API misuse or paid services.
import { readFile } from 'node:fs/promises'
import { execFileSync } from 'node:child_process'

const host = 'camvella.com'
const base = 'https://' + host
const key = '78057e4eedc3de519284327e5fd31bf6'
const sitemap = await readFile(new URL('../dist/sitemap.xml', import.meta.url), 'utf8')
const indexed = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1])
const canonicalUrls = new Set(indexed)
if (indexed.length < 75) throw new Error('Unexpectedly small sitemap; refusing IndexNow submission')

let changes
try {
  changes = execFileSync('git',['diff','--name-only','HEAD^1','HEAD','--'],{encoding:'utf8'}).trim().split('\n').filter(Boolean)
} catch (error) {
  throw new Error('Cannot verify changed source files; refusing to submit all URLs: '+String(error))
}

const urls = new Set()
function add(href) {
  const url = href.startsWith('https://') ? href : base+href
  if (canonicalUrls.has(url)) urls.add(url)
}
const addMatching = (prefix) => indexed.filter(u => u.startsWith(base+prefix)).forEach(add)
for (const file of changes) {
  if (file === 'src/layouts/BaseLayout.astro') { indexed.forEach(add); continue }
  if (file === 'src/data/seoGuides.ts' || file === 'src/pages/guides/[slug].astro') {
    addMatching('/guides/');continue
  }
  if (file === 'src/pages/locations/[state].astro' || file === 'src/data/states.ts') {
    addMatching('/locations/');continue
  }
  if (file.startsWith('src/pages/') && file.endsWith('.astro')) {
    const p=file.slice('src/pages/'.length,-'.astro'.length)
    const path=p==='index' ? '/' : '/'+p.replace(/\/index$/,'')+'/'
    add(path)
  }
}
const submission = [...urls].sort()
if (submission.length===0) {console.log('IndexNow: no changed indexable page content in this commit');process.exit(0)}
console.log(`IndexNow: ${submission.length} changed URLs detected`)

const keyUrl = base+'/'+key+'.txt'
let verified = false
for (let attempt=0;attempt<16;attempt++) {
  try {
    const response=await fetch(keyUrl+'?deploy-check='+Date.now(),{signal:AbortSignal.timeout(10000),headers:{'Cache-Control':'no-cache'}})
    if(response.ok && (await response.text()).trim()===key){verified=true;break}
  }catch{/* a temporary Cloudflare propagation delay is allowed */}
  await new Promise(resolve=>setTimeout(resolve,15000))
}
if(!verified)throw new Error('IndexNow key is not live on Camvella. Cloudflare production is not verified; no URLs submitted.')

const body={host,key,keyLocation:keyUrl,urlList:submission}
const response=await fetch('https://api.indexnow.org/indexnow',{
  method:'POST',headers:{'Content-Type':'application/json; charset=utf-8'},
  body:JSON.stringify(body),signal:AbortSignal.timeout(25000)
})
const result=(await response.text()).slice(0,1000)
if(![200,202].includes(response.status))throw new Error(`IndexNow HTTP ${response.status}: ${result}`)
console.log(`IndexNow accepted: HTTP ${response.status}; ${submission.length} URLs. 202 means key verification pending, not verified indexing.`)
