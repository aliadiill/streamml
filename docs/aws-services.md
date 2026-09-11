# Why I chose these AWS services

I selected this service mix to connect streaming, reliable ingestion and controlled model release while keeping the lab small.

| Service | Problem it solves | Tradeoff and limit |
| --- | --- | --- |
| Kinesis Data Streams | Ordered per-card streaming and replay window | One provisioned shard has ongoing cost; 24-hour retention; required service may be plan-restricted |
| Lambda | Bounded event processing and authenticated metrics reads | Retries require idempotency; shared account concurrency is not a spending cap |
| S3 | Canonical raw events, experiment outputs, website assets | One object per event is acceptable only for this small lab; production analytics needs compaction |
| DynamoDB | Atomic dedup/counters and recent-event reads | Single minute bucket and single timeline partition are deliberate small-volume limits |
| API Gateway + Cognito | Authenticated read API and user sign-in | Browser tokens require XSS protections; hosted login is an external dependency |
| CloudFront | HTTPS static delivery, private S3 access and same-origin API routing | Distribution propagation is slow; API cache is disabled |
| Glue catalog + Athena | SQL exploration without a database server | A catalog definition replaces a crawler; 10 MiB query cap limits accidental scans |
| SageMaker Pipelines + Registry | Managed job dependencies and controlled model versions | Three transient jobs per training run; approval does not imply deployment |
| ECR | Immutable ML container storage and scanning | Tagged images must remain while registry versions reference them |
| EventBridge | Daily drift schedule and failed-pipeline events | Schedule disabled initially; drift and model performance are different signals |
| CloudWatch + SNS | Failure/lag alarms and operations event routing | No delivered alert exists until a confirmed subscription is configured and tested |
| SQS | Failed stream-batch investigation metadata | Not a complete archive of all original records |
| CodePipeline + CodeBuild | GitHub-sourced tests, review and deployment | Main AWS pipeline remains unrun; separate CodeBuild Docker tests and ECR scanning succeeded |

I omitted a persistent SageMaker endpoint, Spark cluster, OpenSearch domain, NAT Gateway, Glue crawler and extra database because they did not justify their cost or complexity for this experiment.

I implemented the complete architecture described above. My actual AWS test used the isolated CodeBuild/ECR/S3/IAM/logging configuration, which I removed after verification. The [published Pages dashboard](pages-preview.md) is hosted separately and blocks AWS connection requests.
