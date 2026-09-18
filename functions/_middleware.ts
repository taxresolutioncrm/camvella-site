interface PagesContext {
  request: Request
  next(): Promise<Response>
}

const CANONICAL_HOST = 'camvella.com'

export async function onRequest(context: PagesContext): Promise<Response> {
  const url = new URL(context.request.url)
  const needsHttps = url.protocol !== 'https:'
  const needsApex = url.hostname === `www.${CANONICAL_HOST}`
  const regionalAliases: Record<string, string> = {
    '/solutions/florida-hoa-management-software': '/locations/florida/',
    '/solutions/florida-hoa-management-software/': '/locations/florida/',
    '/solutions/texas-hoa-management-software': '/locations/texas/',
    '/solutions/texas-hoa-management-software/': '/locations/texas/',
  }
  const regionalCanonical = regionalAliases[url.pathname]

  if (needsHttps || needsApex || regionalCanonical) {
    url.protocol = 'https:'
    if (needsApex) url.hostname = CANONICAL_HOST
    if (regionalCanonical) {
      url.pathname = regionalCanonical
      url.search = ''
      url.hash = ''
    }
    return Response.redirect(url.toString(), 301)
  }

  return context.next()
}
