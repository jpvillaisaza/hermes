import t from 'tap'
import { extractFeeds } from "../src/hermes"

t.test('no feeds', t => {
  const hello = `
    <!doctype html>
    <html>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 0);
  t.end();
});

t.test('alternate feed missing values', t => {
  const hello = `
  <!doctype html>
  <html>
      <head>
        <link rel="alternate">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 0);
  t.end();
});

t.test('RSS', t => {
  const hello = `
    <!doctype html>
    <html>
      <head>
        <link rel="alternate" type="application/rss+xml" href="rss">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 1);
  t.equal(result[0].href, "https://www.example.com/rss");
  t.equal(result[0].title, undefined);
  t.equal(result[0].type, "application/rss+xml");
  t.end();
});

t.test('Atom', t => {
  const hello = `
    <!doctype html>
    <html>
      <head>
        <link rel="alternate" type="application/atom+xml" href="atom">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 1);
  t.equal(result[0].href, "https://www.example.com/atom");
  t.equal(result[0].title, undefined);
  t.equal(result[0].type, "application/atom+xml");
  t.end();
});

t.test('JSON', t => {
  const hello = `
    <!doctype html>
    <html>
      <head>
        <link rel="alternate" type="application/feed+json" href="json">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 1);
  t.equal(result[0].href, "https://www.example.com/json");
  t.equal(result[0].title, undefined);
  t.equal(result[0].type, "application/feed+json");
  t.end();
});

t.test('accepts feed in body', t => {
  const hello = `
    <!doctype html>
    <html>
      <head></head>
      <body>
        <link rel="alternate" type="application/rss+xml" href="rss">
      </body>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 0);
  t.end();
});

t.test('hello test', t => {
  const hello = `
    <!doctype html>
    <html>
      <head></head>
      <body>
        <pre>
          <link rel="alternate" type="application/rss+xml" href="rss">
        </pre>
      </body>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 0);
  t.end();
});

t.test('accepts title', t => {
  const hello = `
    <!doctype html>
    <html>
      <head>
        <link rel="alternate" type="application/rss+xml" href="rss" title="a">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 1);
  t.equal(result[0].href, "https://www.example.com/rss");
  t.equal(result[0].title, "a");
  t.equal(result[0].type, "application/rss+xml");
  t.end();
});

t.test('accepts several', t => {
  const hello = `
    <!doctype html>
    <html>
      <head>
        <link rel="alternate" type="application/rss+xml" href="rss">
        <link rel="alternate" type="application/atom+xml" href="atom">
        <link rel="alternate" type="application/feed+json" href="json">
      </head>
    </html>
  `;
  const result = extractFeeds("https://www.example.com", hello);
  t.equal(result.length, 3);
  t.equal(result[0].href, "https://www.example.com/rss");
  t.equal(result[0].title, undefined);
  t.equal(result[0].type, "application/rss+xml");
  t.equal(result[1].href, "https://www.example.com/atom");
  t.equal(result[1].title, undefined);
  t.equal(result[1].type, "application/atom+xml");
  t.equal(result[2].href, "https://www.example.com/json");
  t.equal(result[2].title, undefined);
  t.equal(result[2].type, "application/feed+json");
  t.end();
});
