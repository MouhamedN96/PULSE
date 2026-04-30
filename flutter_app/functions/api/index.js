const DEFAULT_RAILWAY_API_ORIGIN = "https://pulse-production-62b2.up.railway.app";

export async function onRequest(context) {
  const { request, env } = context;
  const origin = (env.RAILWAY_API_ORIGIN || DEFAULT_RAILWAY_API_ORIGIN).replace(/\/+$/, "");
  const incomingUrl = new URL(request.url);
  const upstreamUrl = new URL(`${origin}/api`);
  upstreamUrl.search = incomingUrl.search;

  return fetch(new Request(upstreamUrl, request), {
    redirect: "follow",
  });
}
