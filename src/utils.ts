export type Result<T> =
  | { ok: true; value: T; }
  | { ok: false; error: string; }

export const fetchWithUserAgent = (
  resource: string | URL | Request,
): Promise<Response> =>
  fetch(resource, {
    "headers": {
      "User-Agent": "hermes/1.0.0",
    },
  });

export const filterAsync = async <T>(
  p: (x: T) => Promise<boolean>,
  xs: T[]
): Promise<T[]> => {
  const results = await Promise.all(
    xs.map(async (x) => {
      const ok = await p(x);
      return ok ? x : null;
    })
  );
  return results.filter(Boolean) as T[];
}
