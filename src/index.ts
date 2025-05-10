#!/usr/bin/env node

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

const extractFeeds = (url: string, html: string): Feed[] => {
  const $ = cheerio.load(html);
  return $('link[rel="alternate"]')
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

const main = async () => {
  const url = process.argv[2];
  if (!url) {
    console.error('Usage: hermes URL');
    process.exit(1);
  }
  const response = await fetch(url);
  if (!response.ok) {
    throw Error(response.statusText);
  }
  const feeds = extractFeeds(url, await response.text());
  feeds.forEach(feed => {
    console.log(`- ${feed.href} (${feed.type})`);
  });
}

main().catch((error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
