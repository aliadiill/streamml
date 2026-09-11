# Security boundaries and reviewed limitations

## Identity and access

Application users sign in through Cognito authorization code with PKCE. The browser generates a random verifier and state, validates returned state and exchanges the code with a public client. Access tokens live in session storage, expire after 15 minutes, and are sent only to the application's API. The implementation does not store credentials or client secrets in the frontend. Session storage still depends on preventing XSS; it is not an HttpOnly cookie.

API Gateway validates JWT issuer, audience/client and the `streamml/read` scope before invoking the metrics handler. The handler independently requires the validated subject claim. The user pool accepts administrator-created users only. The optional MFA configuration allows TOTP; enforcing MFA for every user is an operational hardening step.

Each Lambda has a separate role. The ingest role can write canonical/quarantine objects, transact on the metrics table, consume the one stream and send failure metadata to one queue. The API role reads bounded metric keys and the timeline index. The monitor role can change only CONTROL-prefixed coordination records and read/write defined ML prefixes.

The SageMaker role can read the project's raw/ML objects and write ML outputs; it cannot administer IAM or unrelated buckets. Resource-name wildcards are needed for SageMaker's generated job identifiers. ECR authorization and scoped CloudWatch metric publication require wildcard resources; their rationale is visible in the policy. IAM simulation and live deny tests remain unrun.

## Storage, transport and network

S3 buckets block public access, use server-side encryption, retain object versions and deny non-TLS requests. The website bucket grants read access only to its CloudFront distribution through origin access control. DynamoDB, SQS and Kinesis use encryption at rest. Kinesis uses the AWS-managed streaming key.

The dashboard uses HTTPS, a restrictive response-header policy, frame denial, MIME sniffing protection, HSTS and same-origin API requests. There are no third-party scripts or remote fonts in the shipped interface. API access logs contain request ID, route, status and latency, not tokens.

No custom VPC or NAT is provisioned. Lambda calls managed regional endpoints through AWS's managed environment. SageMaker processing, training and model serving enable network isolation. The image uses only standard-library ML code and has no runtime package-download dependency.

## Input and artifact controls

Events are bounded to 16 KiB at ingestion and rejected for extra fields, malformed identifiers, invalid timestamps, non-finite values or out-of-range features. Conflicting event IDs cannot silently replace raw data. Quarantine stores only a record identifier and reason, not an arbitrary supplied payload.

The ML container does not use pickle or execute downloaded model code. It loads bounded JSON coefficients and extracts only an expected regular tar member. Images are immutable source-tagged artifacts and scanned before deployment. A local structural review is not a substitute for an independent penetration test or an AWS IAM Access Analyzer review.

## Remaining security work

Cloud acceptance must prove unauthorized API denial, correct JWT scope, bucket denial, restricted IAM, encrypted resources and notification handling. Supply-chain locking includes npm's lockfile and Terraform's provider lock; Python cloud-client requirements use bounded ranges rather than a full transitive lock. For a longer-lived service, pin a reviewed Python lock and container digest, add dependency review automation, enforce MFA and perform an independent IAM/IaC assessment.
