import assert from 'node:assert/strict'
import {readFileSync,readdirSync} from 'node:fs'
import {join} from 'node:path'

const layout=readFileSync('src/layouts/BaseLayout.astro','utf8')
assert.equal(layout.split('https://www.googletagmanager.com/gtag/js?id=').length-1,1,'only one shared GA4 script loader')
assert.equal(layout.split('clarity.ms/tag/').length-1,1,'only one shared Clarity script loader')
assert(layout.includes("const CAMVELLA_GA4_ID = 'G-H1ZPCP2EE9'"),'GA4 identity unchanged')
assert(layout.includes("const CAMVELLA_CLARITY_ID = 'y62zna7yna'"),'Clarity identity unchanged')
assert(layout.includes('{CAMVELLA_GA4_ID && ('),'conditional GA4 initialization preserved')
assert(layout.includes('{CAMVELLA_CLARITY_ID && ('),'conditional Clarity initialization preserved')

function walk(dir){
  return readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(join(dir,e.name)):[join(dir,e.name)])
}
const pages=walk('dist').filter(p=>p.endsWith('.html'))
assert(pages.length>0,'Astro output exists')
let checked=0
for(const page of pages){
  const html=readFileSync(page,'utf8')
  if(!html.includes('G-H1ZPCP2EE9'))continue
  const ga=(html.match(/googletagmanager[.]com\/gtag\/js[?]id=G-H1ZPCP2EE9/g)||[]).length
  const clarity=(html.match(/clarity[.]ms\/tag\//g)||[]).length
  assert.equal(ga,1,page+' one GA4 loader')
  assert.equal(clarity,1,page+' one Clarity loader')
  checked++
}
assert(checked>0,'analytics checked in generated pages')
console.log('PASS Camvella analytics initialize once in '+checked+' rendered pages')
