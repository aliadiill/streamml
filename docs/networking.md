# Networking and request flow

The browser reaches a CloudFront HTTPS hostname. Default GET/HEAD traffic serves private S3 objects through origin access control. Requests under `/api/*` go to the API Gateway HTTPS origin. The API behavior uses the managed disabled-cache policy and forwards viewer headers except Host, so JWT Authorization reaches API Gateway without caching per-user responses.

Cognito's hosted login is an HTTPS redirect and PKCE token exchange. The callback returns to the exact root URL registered on the public app client. The SPA needs no client secret. Local development permits the explicit localhost:5173 origin and callback; it is not a wildcard production CORS policy.

The Lambda functions have no VPC attachment. Their only permissions are scoped managed-service API calls. This eliminates NAT Gateway charges and subnet/route complexity for a system with no private RDS/EC2 workload. IAM controls storage and service access; lack of a custom VPC does not make buckets public.

Training and approved serving use SageMaker network isolation. No endpoint is deployed; a transient batch transform consumes S3 input and writes S3 output. If a future use case requires private source systems, add VPC endpoints/subnets and explicitly budget their steady costs. Do not add networking resources solely to enlarge a diagram.

CloudFront's default certificate covers its generated hostname. A custom domain would require a verified domain and an ACM certificate in us-east-1. No DNS registration, purchase or certificate is claimed.

