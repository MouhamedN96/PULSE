const DEFAULT_RAILWAY_API_ORIGIN = "https://pulse-production-62b2.up.railway.app";

export async function onRequest(context) {
  const { request, params, env } = context;
  const origin = (env.RAILWAY_API_ORIGIN || DEFAULT_RAILWAY_API_ORIGIN).replace(/\/+$/, "");
  const path = Array.isArray(params.path)
    ? params.path.join("/")
    : typeof params.path === "string" && params.path.length > 0
      ? params.path
      : "";

  const incomingUrl = new URL(request.url);
  const upstreamUrl = new URL(`${origin}/api/${path}`);
  upstreamUrl.search = incomingUrl.search;

  const upstreamRequest = new Request(upstreamUrl, request);

  return fetch(upstreamRequest, {
    redirect: "follow",
  });
}
