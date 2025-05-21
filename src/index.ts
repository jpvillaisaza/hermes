#!/usr/bin/env node

import { extractFeeds } from "./hermes";

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
