# Final account-plan and reported-cost verification

Read-only snapshot: **2026-09-11T06:32:15.644426+00:00**. I verified my IAM identity and account, then kept account IDs, credit identifiers and raw API responses private. All Cost Explorer dates below are UTC.

**I verified that my account was FREE / ACTIVE with USD 175.84 remaining credits.** The current Free plan expires **2026-12-10 11:21:45 UTC**. I collected this snapshot through read-only billing APIs. The plan fields came from the [GetAccountPlanState API](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_freetier_GetAccountPlanState.html).

I kept lab runs short and aimed for a **one-time $100 credit budget**. I treated my available credit balance as context rather than a reason to expand the experiment.

## Credit balances

I found five enabled promotional grants on my account. Their totals were:

| Measurement | USD |
| --- | ---: |
| Originally issued | 180.00 |
| Remaining balance | 176.05 |
| Estimated remaining balance, including open bills | 175.84 |
| Issued minus estimated remaining | 4.16 |

I calculated the last row from historical account usage and estimated open bills; it is **not the final cost of these portfolio projects**. The estimated balance can change as usage is processed. AWS defines estimated credit amounts as remaining balances including unfinished bills in its [CreditData reference](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_billing_CreditData.html).

## Reported September costs versus credits

I retrieved one Cost Explorer daily-detail response covering September 1 through 2026-09-11. Grouping was service plus record type, filtered to the intended account, using UnblendedCost. Every returned day was marked estimated.

| Service with nonzero reported amount | Positive charges before credits | Credit line items | Net unblended amount |
| --- | ---: | ---: | ---: |
| Amazon Simple Storage Service | $0.0000360825 | $-0.0000360816 | $0.0000000009 |
| EC2 - Other | $0.2008888914 | $-0.2008888688 | $0.0000000226 |
| **Total** | **$0.2009249739** | **$-0.2009249504** | **$0.0000000235** |

For **2026-09-11 itself, I received no service groups from Cost Explorer**. That means the current day's reported breakdown is not yet populated; it does **not** establish zero usage or a final zero-cost result. The month-to-date net rounds to $0.00, with tiny precision residuals shown above. No non-credit negative adjustment was reported.

The new CodeBuild/container and other portfolio activity may appear after this snapshot. AWS refreshes Cost Explorer at least daily, and current-period figures can change. I fetched one Cost Explorer API page; AWS lists $0.01 per paginated API request. That read usage can also arrive later. See [Cost Explorer data and API pricing](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html).

I use this snapshot to track my budget, while recognizing that it cannot establish the final cost of the demonstrations. I verified resource teardown separately and would review the settled billing figures after the reporting delay.
