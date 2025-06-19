import * as cheerio from "cheerio";

type Feed = {
  href: string,
  title?: string,
  type: string,
};

const feedTypes = [
  "application/rss+xml",
  "application/atom+xml",
  "application/feed+json",
  "application/json",
];

export const extractFeeds = (url: string, html: string): Feed[] => {
  const $ = cheerio.load(html);
  return $('head link[rel="alternate"]')
    .get()
    .flatMap((el) => {
      const href = $(el).attr("href");
      const title = $(el).attr("title") || undefined;
      const type = $(el).attr("type");
      if (href && type && feedTypes.includes(type)) {
        return [{
          href: new URL(href, url).toString(),
          title,
          type,
        }]
      }
      return [];
    })
    ;
}

export const checkFeed = async (url: string) => {
  const response = await fetch(url);
  if (!response.ok) {
    return false;
  }
  const json = await response.json();
  return checkJson(json);
}

const checkJson = (json: any): boolean => {
  return (
    typeof json === "object" && json !== null &&
    json.hasOwnProperty("version") && typeof json.version === "string" &&
    json.version.startsWith("https://jsonfeed.org/version/")
  );
}
