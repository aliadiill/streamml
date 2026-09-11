import assert from "node:assert/strict";
import {readFileSync} from "node:fs";

const html = readFileSync(new URL("../dashboard/dist/index.html", import.meta.url), "utf8").replaceAll("&#39;", "'");
assert.match(html, /Content-Security-Policy/);
assert.match(html, /connect-src 'none'/);
assert.match(html, /src="\/streamml\/assets\//);
assert.match(html, /href="\/streamml\/assets\//);
assert.doesNotMatch(html, /(?:src|href)="\/assets\//);
console.log("Pages artifact passed: repository base path and network-blocking policy.");
