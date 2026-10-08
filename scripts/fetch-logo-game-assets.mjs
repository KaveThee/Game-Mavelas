import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";

const outputDir = path.join(process.cwd(), "public/logos");
await mkdir(outputDir, { recursive: true });

const globalTitles = [
  "NVIDIA", "PayPal", "Cisco", "Discord", "Spotify", "Facebook", "YouTube", "Google",
  "Netflix", "LinkedIn", "Telegram", "WhatsApp", "Amazon Web Services", "Microsoft Azure",
  "Disney+", "Apple", "Windows", "Microsoft", "Cloudflare", "Chrome", "Firefox", "Safari",
  "Instagram", "Bitcoin", "Ethereum", "Adobe", "Canva", "Reddit", "Shopify", "Airbnb",
  "Uber", "Ebay", "IBM", "PlayStation", "Xbox", "Slack", "Snapchat", "Pinterest", "GitHub",
  "TikTok", "Zoom", "Android", "Meta", "Notion", "Dropbox", "Stripe", "Google Maps",
  "Google Play", "App Store", "Prime video", "Twitch", "Binance", "X (formerly Twitter)",
  "Google Drive", "Microsoft Teams", "Gmail", "Google Calendar", "Google Sheets", "Google Slides",
  "Google Meet", "Microsoft Excel", "Microsoft Word", "Microsoft PowerPoint", "Microsoft Outlook",
  "Microsoft OneDrive", "Apple Music", "Youtube Music", "Messenger", "Threads", "Bluesky",
  "Roblox", "Steam", "SoundCloud", "Hulu", "Opera", "Brave Browser", "Edge", "Acrobat Reader",
  "Figma", "OpenAI", "Coursera", "Udemy", "GitLab", "Docker", "WordPress", "Salesforce",
  "Coinbase", "Trello", "Asana", "Google Classroom", "Google Chat"
];

const regionalBrands = [
  ["Safaricom", "Safaricom", "Kenya"],
  ["M-PESA", "M-Pesa", "Kenya"],
  ["Kenya Airways", "Kenya Airways", "Kenya"],
  ["Co-operative Bank", "Co-operative Bank of Kenya", "Kenya"],
  ["MTN", "MTN Group", "Africa"],
  ["Jumia", "Jumia", "Africa"],
  ["DStv", "DStv", "Africa"],
  ["Shoprite", "Shoprite (retailer)", "Africa"],
  ["Ethiopian Airlines", "Ethiopian Airlines", "Africa"],
  ["Ecobank", "Ecobank", "Africa"],
  ["Absa", "Absa Group Limited", "Africa"],
  ["Flutterwave", "Flutterwave", "Africa"]
];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const slugify = (value) => value.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
const clean = (value = "") => value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
const escapeXml = (value = "") => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

async function request(url, asJson = true) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await fetch(url, { headers: { "User-Agent": "GameMavelas/1.0 (logo quiz asset importer)" } });
    if (response.ok) return asJson ? response.json() : response;
    if (response.status !== 429) throw new Error(`${response.status} ${url}`);
    await sleep((attempt + 1) * 3000);
  }
  throw new Error(`Rate limit persisted for ${url}`);
}

const svglLibrary = await request("https://api.svgl.app?limit=1000");
const manifest = [];

async function downloadSvgl(title) {
  const item = svglLibrary.find((logo) => logo.title.toLowerCase() === title.toLowerCase());
  if (!item) {
    process.stdout.write(`✗ SVGL missing ${title}\n`);
    return;
  }
  const route = typeof item.route === "string" ? item.route : item.route.light;
  const response = await request(route, false);
  const svg = await response.text();
  const slug = slugify(title.replace(" (formerly Twitter)", ""));
  await writeFile(path.join(outputDir, `${slug}.svg`), svg);
  manifest.push({ slug, name: title.replace(" (formerly Twitter)", ""), src: `/logos/${slug}.svg`, region: "International", provider: "SVGL", source: item.url, assetSource: route });
  process.stdout.write(`✓ SVGL ${title}\n`);
}

for (let index = 0; index < globalTitles.length; index += 10) {
  await Promise.all(globalTitles.slice(index, index + 10).map(downloadSvgl));
}

async function wikimediaLogo([name, pageTitle, region]) {
  try {
    const wikipediaUrl = new URL("https://en.wikipedia.org/w/api.php");
    wikipediaUrl.search = new URLSearchParams({ action: "query", titles: pageTitle, redirects: "1", prop: "pageprops", ppprop: "wikibase_item", format: "json", origin: "*" });
    const wikipedia = await request(wikipediaUrl);
    const page = Object.values(wikipedia.query.pages)[0];
    const qid = page?.pageprops?.wikibase_item;
    let filename;
    if (qid) {
      const entityData = await request(`https://www.wikidata.org/wiki/Special:EntityData/${qid}.json`);
      filename = entityData.entities[qid]?.claims?.P154?.[0]?.mainsnak?.datavalue?.value;
    }

    let commons;
    if (filename) {
      const url = new URL("https://commons.wikimedia.org/w/api.php");
      url.search = new URLSearchParams({ action: "query", titles: `File:${filename}`, prop: "imageinfo", iiprop: "url|mime|extmetadata", iiurlwidth: "720", format: "json", origin: "*" });
      commons = await request(url);
    } else {
      const url = new URL("https://commons.wikimedia.org/w/api.php");
      url.search = new URLSearchParams({ action: "query", generator: "search", gsrnamespace: "6", gsrsearch: `${name} logo`, gsrlimit: "5", prop: "imageinfo", iiprop: "url|mime|extmetadata", iiurlwidth: "720", format: "json", origin: "*" });
      commons = await request(url);
    }
    const pages = Object.values(commons.query?.pages || {});
    const filePage = pages.find((candidate) => candidate.imageinfo?.[0]);
    const info = filePage?.imageinfo?.[0];
    if (!info) throw new Error("No usable Commons logo");

    const imageUrl = info.url?.endsWith(".svg") ? info.url : (info.thumburl ?? info.url);
    const response = await request(imageUrl, false);
    const contentType = response.headers.get("content-type")?.split(";")[0] || "image/png";
    const buffer = Buffer.from(await response.arrayBuffer());
    const slug = slugify(name);
    let svg;
    if (contentType.includes("svg") || imageUrl.toLowerCase().endsWith(".svg")) {
      svg = buffer.toString("utf8");
    } else {
      const encoded = buffer.toString("base64");
      svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 480" role="img" aria-label="${escapeXml(name)} logo"><rect width="720" height="480" rx="36" fill="#fff"/><image x="40" y="40" width="640" height="400" href="data:${contentType};base64,${encoded}" preserveAspectRatio="xMidYMid meet"/></svg>\n`;
    }
    await writeFile(path.join(outputDir, `${slug}.svg`), svg);
    manifest.push({
      slug, name, src: `/logos/${slug}.svg`, region, provider: "Wikimedia Commons",
      source: info.descriptionurl, sourceFile: filePage.title,
      author: clean(info.extmetadata?.Artist?.value || info.extmetadata?.Credit?.value || "Wikimedia Commons contributor"),
      license: clean(info.extmetadata?.LicenseShortName?.value || info.extmetadata?.UsageTerms?.value || "See source"),
      licenseUrl: info.extmetadata?.LicenseUrl?.value || info.descriptionurl,
    });
    process.stdout.write(`✓ ${region} ${name} — ${filePage.title}\n`);
  } catch (error) {
    process.stdout.write(`✗ ${region} ${name} — ${error.message}\n`);
  }
}

for (let index = 0; index < regionalBrands.length; index += 2) {
  await Promise.all(regionalBrands.slice(index, index + 2).map(wikimediaLogo));
  await sleep(500);
}

await writeFile(path.join(outputDir, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
process.stdout.write(`\nSaved ${manifest.length} logo assets.\n`);
