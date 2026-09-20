import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const outputDir = join(root, "public", "clue-heist");

const mysteries = [
  ["cristiano-ronaldo", "Cristiano Ronaldo", "FOOTBALL", "7", "#ef3340", "#0b5c45"],
  ["lionel-messi", "Lionel Messi", "FOOTBALL", "10", "#75aadb", "#f4f4f0"],
  ["lupita-nyongo", "Lupita Nyong'o", "CINEMA", "★", "#7b2cbf", "#f5c542"],
  ["eliud-kipchoge", "Eliud Kipchoge", "MARATHON", "42.2", "#c8102e", "#111111"],
  ["wangari-maathai", "Wangari Maathai", "PLANET", "♧", "#167447", "#d8ef57"],
  ["faith-kipyegon", "Faith Kipyegon", "TRACK", "1500", "#c8102e", "#111111"],
  ["ferdinand-omanyala", "Ferdinand Omanyala", "SPRINT", "100", "#111111", "#d8ef57"],
  ["david-rudisha", "David Rudisha", "TRACK", "800", "#b90e2f", "#f4f4f0"],
  ["nelson-mandela", "Nelson Mandela", "FREEDOM", "27", "#d69f2e", "#186a5b"],
  ["trevor-noah", "Trevor Noah", "COMEDY", "MIC", "#1d2330", "#f5c542"],
  ["burna-boy", "Burna Boy", "MUSIC", "♫", "#171717", "#d4af37"],
  ["mohamed-salah", "Mohamed Salah", "FOOTBALL", "11", "#c8102e", "#f4f4f0"],
  ["didier-drogba", "Didier Drogba", "FOOTBALL", "11", "#034694", "#f4f4f0"],
  ["barack-obama", "Barack Obama", "LEADERSHIP", "44", "#264b76", "#ef3340"],
  ["mekatilili-wa-menza", "Mekatilili wa Menza", "RESISTANCE", "1913", "#8b2f2f", "#e9b949"],
];

function svg([, name, field, mark, primary, accent], index) {
  const tilt = index % 2 === 0 ? -8 : 8;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 900" role="img" aria-labelledby="title desc">
  <title id="title">${name}</title>
  <desc id="desc">Editorial vector reveal poster for ${name}</desc>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#11151a"/><stop offset="1" stop-color="#050607"/></linearGradient>
    <pattern id="grain" width="24" height="24" patternUnits="userSpaceOnUse"><circle cx="3" cy="5" r="1.5" fill="#fff" opacity=".07"/><circle cx="18" cy="15" r="1" fill="#fff" opacity=".05"/></pattern>
    <clipPath id="frame"><rect x="48" y="48" width="1104" height="804" rx="42"/></clipPath>
  </defs>
  <rect width="1200" height="900" fill="url(#bg)"/>
  <g clip-path="url(#frame)">
    <rect x="48" y="48" width="1104" height="804" rx="42" fill="${primary}"/>
    <path d="M-80 780 760-70h520L390 940Z" fill="#080a0d" opacity=".9"/>
    <path d="M760 0h440v900H500Z" fill="${accent}" opacity=".18"/>
    <g transform="translate(635 108) rotate(${tilt} 260 340)">
      <circle cx="260" cy="195" r="132" fill="#090b0e"/>
      <path d="M75 690c6-226 78-355 185-355s179 129 185 355Z" fill="#090b0e"/>
      <path d="M176 306c38 36 130 36 168 0v116c-46 42-122 42-168 0Z" fill="#090b0e"/>
      <path d="M151 179c35-102 183-134 242-27-72-38-160-29-242 27Z" fill="${accent}" opacity=".42"/>
    </g>
    <text x="105" y="145" font-family="Arial Black,Arial,sans-serif" font-size="34" letter-spacing="9" fill="#fff" opacity=".76">CLUE HEIST</text>
    <text x="105" y="230" font-family="Arial Black,Arial,sans-serif" font-size="72" letter-spacing="3" fill="#fff">${field}</text>
    <text x="105" y="710" font-family="Arial Black,Arial,sans-serif" font-size="190" fill="${accent}">${mark}</text>
    <path d="M105 760h390" stroke="#fff" stroke-width="12"/>
    <rect width="1200" height="900" fill="url(#grain)"/>
  </g>
  <rect x="48" y="48" width="1104" height="804" rx="42" fill="none" stroke="#fff" stroke-width="6" opacity=".85"/>
</svg>\n`;
}

await mkdir(outputDir, { recursive: true });
await Promise.all(mysteries.map((mystery, index) => writeFile(join(outputDir, `${mystery[0]}.svg`), svg(mystery, index))));
await writeFile(join(outputDir, "manifest.json"), `${JSON.stringify(mysteries.map(([slug, name]) => ({ slug, name, src: `/clue-heist/${slug}.svg`, alt: `Editorial vector reveal poster for ${name}` })), null, 2)}\n`);
console.log(`Generated ${mysteries.length} Clue Heist SVG reveal posters in ${outputDir}`);
