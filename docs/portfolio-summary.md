# Portfolio description and evidence boundaries

**GitHub description:** Transaction streaming and analytics lab with Kinesis, retry-safe Lambda ingestion, a private data lake, authenticated React dashboard, and gated SageMaker Pipelines.

**Implemented and locally verified:** deterministic transaction generation, validation and replay logic, chronological logistic-regression experiment, quality/release denial tests, React/TypeScript production build, real SageMaker DAG compilation and API argument-shape checks. Terraform and AWS CI/CD definitions are included; see the current testing record for exact validation results.

**Locally measured outcome:** 3,000 synthetic records split 1,800/600/600; held-out F1 0.9298, precision 0.9138 and recall 0.9464. These figures measure this synthetic experiment only.

**Accurate resume bullets at this stage:**

- Implemented a transaction-streaming/MLOps portfolio system with canonical event storage, atomic deduplication counters, an authenticated dashboard and a gated SageMaker workflow.
- Tested retry recovery, malformed records, duplicate conflicts, chronological holdouts, model rejection and denial of unapproved inference; reproduced a 600-record synthetic holdout evaluation.
- Defined Terraform infrastructure and GitHub-to-CodePipeline/CodeBuild delivery with distinct app, model-quality and approval controls; documented current deployment blockers and unrun cloud tests.
- Applied an independent 13-resource Terraform bootstrap and ran actual Docker ML/HTTP checks on transient AWS CodeBuild. Preserved two failed base-image vulnerability gates, then validated an Alpine correction with a completed ECR scan reporting zero findings.
- Removed the temporary AWS bootstrap and verified its resources absent; published a browser-verified [static portfolio preview](https://aliadiill.github.io/streamml/) with labelled sample data and visible GitHub deployment history.

The actual AWS deployment claim is limited to the isolated CodeBuild container demonstration and its verified teardown. The public Pages website is an independently verified static preview. Full streaming, authenticated AWS application and SageMaker execution remain unapplied or unrun. This lab was not operated in production; the [evidence guide](screenshots/README.md) identifies the real screenshots and execution records.
