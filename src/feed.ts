import * as cheerio from "cheerio";
import { Options } from "./options";
import { fetchWithUserAgent, filterAsync } from "./utils";

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

export const run = async (options: Options) => {
  const response = await fetchWithUserAgent(options.url);
  if (!response.ok) {
    throw Error(response.statusText);
  }
  const feeds = extractFeeds(options.url, await response.text());
  const checkedFeeds = options.check ? await filterAsync(checkFeed, feeds) : feeds;
  checkedFeeds.forEach(feed => {
    console.log(`- ${feed.href} (${feed.type})`);
  });
  if (options.guess && checkedFeeds.length === 0) {
    const guessed = await guessFeeds(options.url);
    guessed.forEach(feed => {
      console.log(`- ${feed.href} (${feed.type})`);
    });
  }
}

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

export const checkFeed = async (feed: Feed): Promise<boolean> => {
  const response = await fetchWithUserAgent(feed.href);
  if (!response.ok) return false;
  switch (feed.type) {
    case "application/rss+xml":
    case "application/atom+xml":
      const text = await response.text();
      const $ = cheerio.load(text, { xmlMode: true });
      const rootTag = $.root().children().first().get(0);
      return (rootTag && (rootTag.tagName === "rss" || rootTag.tagName === "feed"));
    case "application/feed+json":
    case "application/json":
      const json = await response.json();
      return isJsonFeed(json);
    default:
      return false;
  }
}

const isJsonFeed = (json: any): boolean => {
  return (
    typeof json === "object" && json !== null &&
    json.hasOwnProperty("version") && typeof json.version === "string" &&
    json.version.startsWith("https://jsonfeed.org/version/")
  );
}

export const guessFeeds = async (url: string): Promise<Feed[]> => {
  const base = url.endsWith("/") ? url : url + "/";
  const feeds = [
    {
      href: new URL("rss.xml", base).toString(),
      type: "application/rss+xml",
    },
    {
      href: new URL("atom.xml", base).toString(),
      type: "application/atom+xml",
    },
    {
      href: new URL("feed", base).toString(),
      type: "application/rss+xml",
    },
    {
      href: new URL("rss", base).toString(),
      type: "application/rss+xml",
    },
  ];
  return await filterAsync(checkFeed, feeds);
}
