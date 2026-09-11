# Public portfolio preview

[Open the published preview](https://aliadiill.github.io/streamml/). On 2026-09-11 UTC, the browser verification confirmed that the dashboard automatically opened with SAMPLE DATA and Portfolio preview labels, rendered its transaction and governance sections, and exposed working navigation links.

The [Pages workflow run 34569734895](https://github.com/aliadiill/streamml/actions/runs/34569734895) **SUCCEEDED** for published commit `fc2a698`. The repository website field points to the preview, and the `github-pages` environment records its deployment history. See the [actual published-page screenshot](screenshots/streamml-github-pages.png) and [machine-readable verification](evidence/pages-deployment.json).

The Pages artifact is a static, explicitly labelled sample dashboard. It starts with illustrative synthetic values, has no Cognito sign-in button, ignores tokens and authorization callbacks, and never polls the AWS API. Its HTML security policy blocks all connection requests with `connect-src 'none'`. It therefore does not create AWS service usage.

From the repository root:

```bash
cd dashboard
npm ci
npm run build:pages
cd ..
node scripts/check_pages.mjs
```

The build uses `/streamml/` for asset and home links. `npm run build` produces the separate normal AWS dashboard. Keep preview configuration out of the normal deployment path.

The workflow `.github/workflows/pages.yml` runs on relevant main-branch changes or manual dispatch. It requires Pages to use GitHub Actions as its publishing source. Its deployment job uses the `github-pages` environment and publishes the returned website URL in the job, creating visible deployment history. The build job has read-only repository permission; only deployment gets Pages write and OIDC permission. It uses no AWS credentials or secrets.

Both normal and Pages TypeScript/Vite builds passed locally on 2026-09-11 UTC. The artifact check verified repository-relative asset paths and the connection-blocking security policy; the successful workflow and live browser check then verified publication. This public sample is separate from the successful AWS Docker ML/ECR demonstration, whose temporary resources were removed. Full Kinesis ingestion, Cognito authorization and SageMaker execution remain unapplied or unrun.
