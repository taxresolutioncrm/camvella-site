// Camvella editorial image uniqueness guard.
// Audit the images users actually see on rendered editorial pages, not every
// unused library asset. Different URL crop/quality params are the same photo.
import { readFileSync, readdirSync } from 'node:fs'
import { join, relative } from 'node:path'

const root = new URL('../src/pages/', import.meta.url)
const component = readFileSync(new URL('../src/components/CommunityPhoto.astro', import.meta.url),'utf8')
const photos = new Map()
for (const m of component.matchAll(/(?:['"]([^'"]+)['"]|([\w-]+)):\s*\{\s*src:\s*['"]https:\/\/images\.unsplash\.com\/(photo-[\w-]+)/g)) {
  photos.set(m[1] || m[2],m[3])
}
const pages = []
function walk(dir) {
  for (const entry of readdirSync(dir,{withFileTypes:true})) {
    const path=join(dir,entry.name)
    if(entry.isDirectory())walk(path)
    else if(entry.isFile() && path.endsWith('.astro'))pages.push(path)
  }
}
walk(new URL('.',root).pathname)
const usages=new Map()
const errors=[]
for(const path of pages) {
  const rel=relative(new URL('.',root).pathname,path)
  const code=readFileSync(path,'utf8')
  const ids=[
    ...[...code.matchAll(/images\.unsplash\.com\/(photo-[\w-]+)/g)].map(m=>m[1]),
    ...[...code.matchAll(/<CommunityPhoto\b[^>]*\bimage="([^"]+)"/g)].map(m=>{
      if(!photos.has(m[1]))errors.push(`${rel}: unknown CommunityPhoto image key ${m[1]}`)
      return photos.get(m[1])
    }).filter(Boolean)
  ]
  for(const id of ids)usages.set(id,[...(usages.get(id)||[]),rel])
}
for(const [id,paths] of usages)if(paths.length>1)errors.push(`Repeated editorial photograph ${id} in: ${paths.join(', ')}`)
if(errors.length) {
 console.error('Camvella editorial photography audit FAILED:\n'+errors.map(x=>' - '+x).join('\n'))
 process.exitCode=1
} else {
 console.log(`Camvella editorial image audit PASS: ${usages.size} distinct photos across ${pages.length} source pages.`)
}
