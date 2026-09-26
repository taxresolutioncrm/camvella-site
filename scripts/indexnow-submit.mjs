const host="camvella.com"
const key="f67ecfad6f55b0fca8f66ecfeb7c1f9d"
const keyLocation=`https://${host}/${key}.txt`
const sitemapUrl="https://camvella.com/sitemap.xml"

function locs(xml){
  return [...String(xml||'').matchAll(/<loc>\s*([^<]+?)\s*<\/loc>/gi)]
    .map(m=>String(m[1]||'').trim())
    .filter(Boolean)
}

async function sitemapUrls(url){
  const r=await fetch(url,{headers:{'user-agent':'RomyLabs-IndexNow/1.0'}})
  if(!r.ok) throw new Error(`Sitemap fetch failed (${r.status}) for ${url}`)
  const xml=await r.text()
  const found=locs(xml)
  const childMaps=found.filter(u=>/\.xml(?:$|\?)/i.test(u))
  const pages=found.filter(u=>!childMaps.includes(u))
  for(const child of childMaps.slice(0,10)){
    const c=await fetch(child,{headers:{'user-agent':'RomyLabs-IndexNow/1.0'}})
    if(c.ok) pages.push(...locs(await c.text()))
  }
  return [...new Set(pages)].filter(u=>{
    try{return new URL(u).hostname.replace(/^www\./,'')===host}catch{return false}
  })
}

const urlList=await sitemapUrls(sitemapUrl)
if(!urlList.length) throw new Error(`No canonical URLs discovered for ${host}`)

if(process.env.INDEXNOW_DRY_RUN==='1'){
  console.log(JSON.stringify({host,keyLocation,sitemapUrl,urlCount:urlList.length,sample:urlList.slice(0,10)},null,2))
  process.exit(0)
}

const response=await fetch('https://api.indexnow.org/indexnow',{
  method:'POST',
  headers:{'content-type':'application/json; charset=utf-8'},
  body:JSON.stringify({host,key,keyLocation,urlList:urlList.slice(0,10000)})
})
const body=await response.text()
if(!response.ok) throw new Error(`IndexNow submission failed (${response.status}): ${body}`)
console.log(`IndexNow accepted ${urlList.length} ${host} URLs (${response.status}).`)
