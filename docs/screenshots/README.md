# Screenshot evidence

All screenshots listed here are actual browser captures from 2026-09-11, with illustrative data clearly labelled.

| Capture | What was verified |
| --- | --- |
| [Published GitHub Pages dashboard](streamml-github-pages.png) | The [public preview](https://aliadiill.github.io/streamml/) rendered automatically in sample mode. Its [Pages deployment workflow](https://github.com/aliadiill/streamml/actions/runs/34569734895) succeeded. The static preview makes no AWS connection. |
| [Earlier local dashboard](streamml-sample-dashboard.png) | The running local React interface displayed its labelled sample metrics and transactions. |
| [Local governance and transaction feed](streamml-governance-preview.png) | The local preview displayed the workflow design and illustrative transaction feed. |

The independent AWS CodeBuild demonstration also completed real Docker preprocessing, training, quality rejection, HTTP predictions and a successful ECR scan after two failed Debian-image gates. Its [sanitized execution and teardown evidence](../evidence/container-execution.json) preserves all three attempts and verified resource removal. The actual AWS build-history screenshot and detailed logs remain private because they include account-specific identifiers. These results do not claim a full Kinesis or SageMaker deployment.

During any future authorized full-stack cloud acceptance, capture the authenticated dashboard, private storage configuration, stream counters, an actual CodePipeline run, SageMaker graph, quality report, pending registry package, approved batch output, and rejection/failure behavior. Those tests remain unrun. Mask account IDs, tokens, email addresses and unnecessary resource identifiers before publishing.

Do not fabricate a successful pipeline screenshot from the architecture diagram. The diagram describes the implemented design; an execution screenshot describes a real observed run.
