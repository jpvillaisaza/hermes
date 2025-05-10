import * as cheerio from "cheerio";

const fetchHtml = async (url: string): Promise<string> => {
  const response = await fetch(url);
  if (!response.ok) {
    throw Error(response.statusText);
  }
  return await response.text();
}

const extractFeedLinks = (html: string, baseUrl: string): string[] => {
  const $ = cheerio.load(html);
  return $('link[rel="alternate"]')
    .map((_, el) => $(el).attr('href'))
    .get()
    .map((href) => new URL(href, baseUrl).toString())
    ;
}

const main = async () => {
  const url = process.argv[2];
  if (!url) {
    console.error('Usage: hermes URL');
    process.exit(1);
  }

  const html = await fetchHtml(url);
  const feeds = extractFeedLinks(html, url);

  if (feeds.length) {
    console.log('Feeds:');
    feeds.forEach((feed, _) => console.log(`- ${feed}`));
  } else {
    console.log("No feed links found.");
  }
}

main().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
