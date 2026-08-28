interface PagesContext {
  request: Request
  next(): Promise<Response>
}

export async function onRequest(context: PagesContext): Promise<Response> {
  const url = new URL(context.request.url)

  if (url.hostname === 'camvella.com') {
    url.hostname = 'www.camvella.com'
    return Response.redirect(url.toString(), 301)
  }

  return context.next()
}
