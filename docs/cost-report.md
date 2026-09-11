# My AWS portfolio cost report

**Ali Adil · CloudPress, ThreatLens and StreamML · 11 September 2026**

I wanted these projects to demonstrate real cloud engineering without leaving an expensive lab running. I set a **one-time $100 AWS credit budget**, used short deployments for evidence, and hosted the lasting previews on GitHub Pages. I chose services for the workload, kept test traffic small, and included teardown in the delivery process.

## Consolidated billing snapshot

I collected this account-wide snapshot from the AWS Free Tier, Billing and Cost Explorer APIs at **06:32 UTC on 11 September 2026**. It covers the account, including earlier learning activity; it is not a bill allocated to these three projects.

| AWS-reported measurement | Amount |
|---|---:|
| Estimated remaining promotional credits | **$175.84** |
| September reported charges before credits | $0.200925 |
| September reported credit offsets | -$0.200925 |
| September reported net, rounded | $0.00 |
| New project-day breakdown | Not populated yet |

The account remained on its Free plan. Five promotional grants originally totaled $180; the $4.16 difference from the estimated remaining balance includes historical activity and open estimates. I do **not** label that difference as the cost of this portfolio.

## How I controlled operating cost

| Project | What I ran and measured | Cost decision |
|---|---|---|
| CloudPress | Real WordPress on two private EC2 instances, RDS and EFS; successful AWS pipeline and public page/health tests | Short lab window, one lab NAT, small instances, then Terraform teardown |
| ThreatLens | Live event processing, replay checks, protected APIs and Cognito MFA browser tests | Request-driven services, synthetic traffic, simulated notifications, then verified deletion of the 75-resource stack |
| StreamML | Three actual Docker builds in transient CodeBuild; final functional tests and ECR scan passed | Ten-minute build caps; isolated build stack, no always-running ML endpoint; build resources deleted and checked absent |

## Forecast and interpretation

I use the per-project cost guides as planning estimates, and AWS billing as the eventual record of charges. At this snapshot, Cost Explorer had not populated 11 September's service breakdown. I therefore do not publish a made-up final project bill or an AWS-generated forecast. The earlier CloudPress planning allowance was roughly $0.40–$1.50 for a two-hour lab, with $2 reserved for a three-hour troubleshooting window; that is a planning allowance, not a measured invoice.

After project teardown, the public demos run on GitHub Pages without connecting to AWS. I verify removal of compute, databases, storage and pipelines separately from the billing snapshot. ThreatLens's automatic DynamoDB SYSTEM backup and scheduled KMS key deletion expire on 18 September; the documented waiting periods add no backup/key-storage charge. Historical request and runtime charges can still appear later.

For the exact API-derived figures and source definitions, see [my detailed billing snapshot](credit-budget-verification.md). The individual testing and teardown records show what I actually ran. This is the cost discipline I wanted to demonstrate: plan, observe, clean up, and distinguish estimates from posted charges.
