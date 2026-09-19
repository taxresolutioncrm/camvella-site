import { cp, mkdir, readdir, readFile, rm, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'

const root = process.cwd()
const dist = path.join(root, 'dist')
await rm(dist, { recursive: true, force: true })
await mkdir(dist, { recursive: true })

const entries = await readdir(root)
for (const name of entries) {
  if (['dist','node_modules','package.json','build.mjs','wrangler.jsonc'].includes(name)) continue
  const src = path.join(root, name)
  const dst = path.join(dist, name)
  const info = await stat(src)
  if (info.isDirectory()) await cp(src, dst, { recursive: true })
  else await cp(src, dst)
}

const ga4Id = 'G-BBHLF92295'
const clarityId = 'ygv0xf8tea'
const analytics = `(() => {
  const GA4_ID = ${JSON.stringify(ga4Id)};
  const CLARITY_ID = ${JSON.stringify(clarityId)};
  window.dataLayer = window.dataLayer || [];
  window.gtag = window.gtag || function(){ window.dataLayer.push(arguments); };
  if (GA4_ID) {
    const s = document.createElement('script');
    s.async = true;
    s.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(GA4_ID);
    document.head.appendChild(s);
    window.gtag('js', new Date());
    window.gtag('config', GA4_ID, { page_path: window.location.pathname });
  }
  if (CLARITY_ID) {
    (function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src='https://www.clarity.ms/tag/'+i;y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y)})(window,document,'clarity','script',CLARITY_ID);
  }
})();`
await writeFile(path.join(dist, 'analytics.js'), analytics, 'utf8')
const brandLogo = path.resolve(root, '..', 'public', 'groundivo-logo.svg')
await cp(brandLogo, path.join(dist, 'groundivo-logo.svg'))

async function injectAnalytics(dir) {
  for (const name of await readdir(dir)) {
    const file = path.join(dir, name)
    const info = await stat(file)
    if (info.isDirectory()) { await injectAnalytics(file); continue }
    if (!name.endsWith('.html')) continue
    let html = await readFile(file, 'utf8')
    if (!html.includes('/favicon.svg?v=20260918')) {
      html = html.replace(/<\/head>/i, '<link rel="icon" type="image/svg+xml" sizes="any" href="/favicon.svg?v=20260918"><link rel="shortcut icon" href="/favicon.svg?v=20260918"><\/head>')
    }
    if (!html.includes('/analytics.js')) {
      html = html.replace(/<\/head>/i, '<script src="/analytics.js" defer><\/script><\/head>')
    }
    await writeFile(file, html, 'utf8')
  }
}
await injectAnalytics(dist)

console.log(`Groundivo marketing site built to marketing-site/dist (GA4 ${ga4Id ? 'configured' : 'not configured'}, Clarity ${clarityId ? 'configured' : 'not configured'})`)
