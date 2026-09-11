# Screenshot evidence

I captured these screenshots in the browser on 2026-09-11 and labelled the illustrative data clearly.

| Capture | What was verified |
| --- | --- |
| [Published GitHub Pages dashboard](streamml-github-pages.png) | The [public preview](https://aliadiill.github.io/streamml/) rendered automatically in sample mode. Its [Pages deployment workflow](https://github.com/aliadiill/streamml/actions/runs/34569734895) succeeded. The static preview makes no AWS connection. |
| [Earlier local dashboard](streamml-sample-dashboard.png) | The running local React interface displayed its labelled sample metrics and transactions. |
| [Local governance and transaction feed](streamml-governance-preview.png) | The local preview displayed the workflow design and illustrative transaction feed. |

I also completed an independent AWS CodeBuild demonstration with real Docker preprocessing, training, quality rejection, HTTP predictions and a successful ECR scan after two failed Debian-image gates. Its [sanitized execution and teardown evidence](../evidence/container-execution.json) preserves all three attempts and verified resource removal. I kept the AWS build-history screenshot and detailed logs private because they include account-specific identifiers. I have not deployed the full Kinesis or SageMaker stack.

For my future full-stack cloud tests, I would capture the authenticated dashboard, private storage configuration, stream counters, an actual CodePipeline run, SageMaker graph, quality report, pending registry package, approved batch output, and rejection/failure behavior. Those tests remain unrun. I redact account IDs, tokens, email addresses and unnecessary resource identifiers before publication.

I use architecture diagrams to explain my design and execution screenshots to show observed runs. I keep those evidence types separate.
