const CANONICAL_HOST = 'camvella.com'

export async function onRequest(context) {
  const url = new URL(context.request.url)
  const needsHttps = url.protocol !== 'https:'
  const needsApex = url.hostname === `www.${CANONICAL_HOST}`

  if (needsHttps || needsApex) {
    url.protocol = 'https:'
    url.hostname = CANONICAL_HOST
    return Response.redirect(url.toString(), 301)
  }

  return context.next()
}
