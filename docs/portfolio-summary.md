# Portfolio description and evidence boundaries

**My project:** I built a transaction streaming and analytics lab with Kinesis, retry-safe Lambda ingestion, a private data lake, authenticated React dashboard, and gated SageMaker Pipelines.

**What I implemented and tested locally:** deterministic transaction generation, validation and replay logic, chronological logistic-regression experiment, quality/release denial tests, React/TypeScript production build, real SageMaker DAG compilation and API argument-shape checks. Terraform and AWS CI/CD definitions are included; see the current testing record for exact validation results.

**My measured outcome:** 3,000 synthetic records split 1,800/600/600; held-out F1 0.9298, precision 0.9138 and recall 0.9464. These figures measure this synthetic experiment only.

**How I describe the work:**

- I implemented a transaction-streaming/MLOps portfolio system with canonical event storage, atomic deduplication counters, an authenticated dashboard and a gated SageMaker workflow.
- I tested retry recovery, malformed records, duplicate conflicts, chronological holdouts, model rejection and denial of unapproved inference; reproduced a 600-record synthetic holdout evaluation.
- I defined Terraform infrastructure and GitHub-to-CodePipeline/CodeBuild delivery with distinct app, model-quality and approval controls; documented current deployment blockers and unrun cloud tests.
- I applied an independent 13-resource Terraform bootstrap and ran actual Docker ML/HTTP checks on transient AWS CodeBuild. Preserved two failed base-image vulnerability gates, then validated an Alpine correction with a completed ECR scan reporting zero findings.
- I removed the temporary AWS bootstrap and verified its resources absent; published a browser-verified [static portfolio preview](https://aliadiill.github.io/streamml/) with labelled sample data and visible GitHub deployment history.

I deployed and tested the isolated CodeBuild container experiment, verified its teardown and published the static Pages preview. I have not deployed the full streaming/authenticated application or executed SageMaker, and I have not operated this lab in production; the [evidence guide](screenshots/README.md) identifies the real screenshots and execution records.
