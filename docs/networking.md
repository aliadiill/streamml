# Networking and request flow

I designed the AWS request path around a CloudFront HTTPS hostname. Default GET/HEAD traffic serves private S3 objects through origin access control. Requests under `/api/*` go to the API Gateway HTTPS origin. The API behavior uses the managed disabled-cache policy and forwards viewer headers except Host, so JWT Authorization reaches API Gateway without caching per-user responses.

I implemented hosted Cognito login through HTTPS redirects and a PKCE token exchange. The callback must match the exact base URL registered on the public app client. The SPA needs no client secret. Local development permits the explicit localhost:5173 origin and callback; it is not a wildcard production CORS policy.

I left the Lambda functions outside a custom VPC. Their only permissions are scoped managed-service API calls. This eliminates NAT Gateway charges and subnet/route complexity for a system with no private RDS/EC2 workload. IAM controls storage and service access; lack of a custom VPC does not make buckets public.

I enabled network isolation in the SageMaker training and approved-serving definitions. No endpoint is deployed; a transient batch transform consumes S3 input and writes S3 output. If I connect a private source system later, I would add the necessary endpoints/subnets and budget their steady costs. I avoided networking resources without a workload requirement.

I selected CloudFront's default certificate for the generated hostname. A custom domain would require a verified domain and an ACM certificate in us-east-1. I did not register a domain or provision a custom certificate.

