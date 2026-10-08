import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();
const manifestPath = path.join(root, "public/celebrities/manifest.json");
const currentManifest = JSON.parse(await readFile(manifestPath, "utf8"));
const catalog = JSON.parse(await readFile(path.join(root, "scripts/who-am-i-catalog.json"), "utf8"));
const existingSlugs = new Set(currentManifest.map((person) => person.slug));
const additions = catalog
  .filter((person) => !existingSlugs.has(person.slug))
  .map((person) => ({
    slug: person.slug,
    name: person.displayName ?? person.name,
    lookupName: person.name,
    src: `/celebrities/${person.slug}.svg`,
    alt: `Photograph of ${person.displayName ?? person.name}`,
    region: person.region,
    field: person.field,
    difficulty: person.difficulty,
  }));
const manifest = [...currentManifest, ...additions];

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const clean = (value = "") => value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
const escapeXml = (value = "") => value
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;");

async function getJson(url) {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await fetch(url, { headers: { "User-Agent": "GameMavelas/1.0 (party quiz asset importer)" } });
    if (response.ok) return response.json();
    if (response.status !== 429) throw new Error(`${response.status} ${url}`);
    await sleep((attempt + 1) * 3500);
  }
  throw new Error(`Rate limit persisted for ${url}`);
}

async function resolvePortrait(name) {
  const wikipediaUrl = new URL("https://en.wikipedia.org/w/api.php");
  wikipediaUrl.search = new URLSearchParams({
    action: "query",
    titles: name,
    redirects: "1",
    prop: "pageprops",
    ppprop: "wikibase_item",
    format: "json",
    origin: "*",
  });
  const wikipedia = await getJson(wikipediaUrl);
  const wikipediaPage = Object.values(wikipedia.query.pages)[0];
  let qid = wikipediaPage?.pageprops?.wikibase_item;

  if (!qid) {
  const searchUrl = new URL("https://www.wikidata.org/w/api.php");
  searchUrl.search = new URLSearchParams({
    action: "wbsearchentities",
    search: name,
    language: "en",
    uselang: "en",
    type: "item",
    limit: "8",
    format: "json",
    origin: "*",
  });
  const search = await getJson(searchUrl);
  const exact = search.search.find((item) => item.label?.localeCompare(name, undefined, { sensitivity: "base" }) === 0);
  const candidate = exact ?? search.search[0];
  if (!candidate) throw new Error(`No Wikidata entity found for ${name}`);
    qid = candidate.id;
  }

  const entityData = await getJson(`https://www.wikidata.org/wiki/Special:EntityData/${qid}.json`);
  const entity = entityData.entities[qid];
  const filename = entity?.claims?.P18?.[0]?.mainsnak?.datavalue?.value;
  if (!filename) throw new Error(`No Wikimedia Commons portrait found for ${name} (${qid})`);

  const commonsUrl = new URL("https://commons.wikimedia.org/w/api.php");
  commonsUrl.search = new URLSearchParams({
    action: "query",
    titles: `File:${filename}`,
    prop: "imageinfo",
    iiprop: "url|size|mime|extmetadata",
    iiurlwidth: "512",
    format: "json",
    origin: "*",
  });
  const commons = await getJson(commonsUrl);
  const page = Object.values(commons.query.pages)[0];
  const info = page.imageinfo?.[0];
  if (!info?.thumburl && !info?.url) throw new Error(`No downloadable portrait for ${name}`);

  return {
    qid,
    description: "",
    filename,
    source: info.descriptionurl,
    imageUrl: info.thumburl ?? info.url,
    author: clean(info.extmetadata?.Artist?.value || info.extmetadata?.Credit?.value || "Wikimedia Commons contributor"),
    license: clean(info.extmetadata?.LicenseShortName?.value || info.extmetadata?.UsageTerms?.value || "See source"),
    licenseUrl: info.extmetadata?.LicenseUrl?.value || info.descriptionurl,
  };
}

const failures = [];
async function downloadPerson(person) {
  if (person.provider === "Wikimedia Commons" && person.source) return person;
  try {
    const portrait = await resolvePortrait(person.lookupName ?? person.name);
    const response = await fetch(portrait.imageUrl, { headers: { "User-Agent": "GameMavelas/1.0 (party quiz asset importer)" } });
    if (!response.ok) throw new Error(`Could not download portrait (${response.status})`);
    const mime = response.headers.get("content-type")?.split(";")[0] || "image/jpeg";
    const imageData = Buffer.from(await response.arrayBuffer()).toString("base64");
    const metadata = escapeXml(JSON.stringify({
      source: portrait.source,
      sourceFile: portrait.filename,
      author: portrait.author,
      license: portrait.license,
      licenseUrl: portrait.licenseUrl,
      wikidata: portrait.qid,
    }));
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 720 720" role="img" aria-labelledby="title desc">
  <title id="title">${escapeXml(person.name)}</title>
  <desc id="desc">Authentic photograph of ${escapeXml(person.name)}, sourced from Wikimedia Commons.</desc>
  <metadata>${metadata}</metadata>
  <defs><clipPath id="portrait"><rect width="720" height="720" rx="42"/></clipPath></defs>
  <rect width="720" height="720" rx="42" fill="#f0eee8"/>
  <image width="720" height="720" href="data:${mime};base64,${imageData}" preserveAspectRatio="xMidYMid slice" clip-path="url(#portrait)"/>
</svg>
`;
    await writeFile(path.join(root, "public/celebrities", `${person.slug}.svg`), svg);
    const record = {
      ...person,
      lookupName: undefined,
      alt: `Photograph of ${person.name}`,
      provider: "Wikimedia Commons",
      wikidata: portrait.qid,
      source: portrait.source,
      sourceFile: portrait.filename,
      author: portrait.author,
      license: portrait.license,
      licenseUrl: portrait.licenseUrl,
    };
    process.stdout.write(`✓ ${person.name} — ${portrait.qid} — ${portrait.filename}\n`);
    return record;
  } catch (error) {
    failures.push({ name: person.name, error: error.message });
    process.stdout.write(`✗ ${person.name} — ${error.message}\n`);
    return person;
  }
}

const updated = [];
for (let index = 0; index < manifest.length; index += 2) {
  const batch = manifest.slice(index, index + 2);
  updated.push(...await Promise.all(batch.map(downloadPerson)));
  await sleep(600);
}

await writeFile(manifestPath, `${JSON.stringify(updated, null, 2)}\n`);
if (failures.length) {
  process.stderr.write(`\n${failures.length} portraits need manual review:\n${JSON.stringify(failures, null, 2)}\n`);
  process.exitCode = 2;
}
