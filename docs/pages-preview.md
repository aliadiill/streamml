# Public portfolio preview

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

Both normal and Pages TypeScript/Vite builds were checked locally on 2026-09-11 UTC. The artifact check verified repository-relative asset paths and the connection-blocking security policy. A live Pages URL and successful workflow history must be verified separately after the owner publishes the repository changes. The sample preview cannot establish live streaming, Cognito authorization or model-pipeline execution.
