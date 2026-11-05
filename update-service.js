import { LATEST_RELEASE, PUBLIC_ORIGIN } from "./release-state.js";

export const UPDATE_VERSION_PATH = "/update/version/latest";

const EXPECTED_PUBLIC_HOST = "rsc.charisk.top";
const RELEASE_ID_PATTERN = /^v[0-9]+\.[0-9]+\.[0-9]+$/;
const VERSION_PATTERN = /^[0-9]+\.[0-9]+\.[0-9]+$/;

function configuredPublicOrigin() {
  let url;
  try {
    url = new URL(PUBLIC_ORIGIN);
  } catch {
    throw new Error("PUBLIC_ORIGIN must be https://rsc.charisk.top");
  }
  if (
    url.protocol !== "https:" ||
    url.hostname.toLowerCase() !== EXPECTED_PUBLIC_HOST ||
    url.port ||
    url.username ||
    url.password ||
    url.pathname !== "/" ||
    url.search ||
    url.hash
  ) {
    throw new Error("PUBLIC_ORIGIN must be https://rsc.charisk.top");
  }
  return url.origin;
}

const publicOrigin = configuredPublicOrigin();

function validateLatestRelease(release) {
  if (release === null) {
    return null;
  }
  if (!release || typeof release !== "object") {
    throw new Error("LATEST_RELEASE must be null or an object");
  }

  const { id, version } = release;
  if (
    typeof id !== "string" ||
    typeof version !== "string" ||
    !RELEASE_ID_PATTERN.test(id) ||
    !VERSION_PATTERN.test(version) ||
    id !== `v${version}`
  ) {
    throw new Error("LATEST_RELEASE must use matching vX.Y.Z and X.Y.Z values");
  }
  return { id, version };
}

export function latestUpdateUrl(release = LATEST_RELEASE) {
  const validatedRelease = validateLatestRelease(release);
  return validatedRelease === null
    ? ""
    : `${publicOrigin}/update/releases/${validatedRelease.id}`;
}

function response(body, status, headers = {}) {
  return new Response(body, {
    status,
    headers: {
      "cache-control": "no-store, max-age=0",
      "content-security-policy": "default-src 'none'; base-uri 'none'; frame-ancestors 'none'",
      "x-content-type-options": "nosniff",
      ...headers,
    },
  });
}

function jsonResponse(value) {
  return response(JSON.stringify(value), 200, {
    "content-type": "application/json; charset=utf-8",
  });
}

export async function handleRequest(request) {
  let url;
  try {
    url = new URL(request.url);
  } catch {
    return response("Bad request\n", 400, {
      "content-type": "text/plain; charset=utf-8",
    });
  }
  if (url.pathname !== UPDATE_VERSION_PATH) {
    return response("Not found\n", 404, {
      "content-type": "text/plain; charset=utf-8",
    });
  }
  if (request.method !== "POST") {
    return response("Method not allowed\n", 405, {
      allow: "POST",
      "content-type": "text/plain; charset=utf-8",
    });
  }

  return jsonResponse({ url: latestUpdateUrl() });
}

export default {
  fetch(request) {
    return handleRequest(request);
  },
};
