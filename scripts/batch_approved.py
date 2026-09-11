"""Run one bounded batch job from an already Approved registry version."""
import argparse
import json
import tarfile
import time
import uuid
from io import BytesIO
from urllib.parse import urlparse


def run(sm, s3, arn, role, data, output, bucket, seconds=900):
    package = sm.describe_model_package(ModelPackageName=arn)
    if package.get("ModelApprovalStatus") != "Approved":
        raise ValueError("Registry version must be Approved before batch inference")
    if not 60 <= seconds <= 1800:
        raise ValueError("Deadline must be 60..1800 seconds")
    for uri in (data, output):
        parsed = urlparse(uri)
        if parsed.scheme != "s3" or parsed.netloc != bucket or not parsed.path.startswith("/ml/"):
            raise ValueError("Input/output must be within this project's ml/ prefix")
    # The caller must use a bounded inference file, not an unbounded bucket prefix.
    parsed = urlparse(data)
    key = parsed.path.lstrip("/")
    objects = s3.list_objects_v2(Bucket=bucket, Prefix=key, MaxKeys=2)
    if objects.get("IsTruncated") or [o["Key"] for o in objects.get("Contents", [])] != [key]:
        raise ValueError("Input prefix must resolve to exactly the nominated object")
    if s3.head_object(Bucket=bucket, Key=key)["ContentLength"] > 1048576:
        raise ValueError("Batch input must be a single object <=1 MiB")
    name = "streamml-" + uuid.uuid4().hex[:16]
    sm.create_model(ModelName=name, ExecutionRoleArn=role,
                    PrimaryContainer={"ModelPackageName": arn}, EnableNetworkIsolation=True)
    created, terminal = False, False
    try:
        sm.create_transform_job(TransformJobName=name, ModelName=name,
            MaxConcurrentTransforms=1, MaxPayloadInMB=1, BatchStrategy="SingleRecord",
            ModelClientConfig={"InvocationsTimeoutInSeconds": 60, "InvocationsMaxRetries": 1},
            TransformInput={"DataSource": {"S3DataSource": {"S3DataType": "S3Prefix", "S3Uri": data}},
                            "ContentType": "application/jsonlines", "SplitType": "Line"},
            TransformOutput={"S3OutputPath": output, "Accept": "application/jsonlines", "AssembleWith": "Line"},
            TransformResources={"InstanceType": "ml.m5.large", "InstanceCount": 1})
        created = True
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            status = sm.describe_transform_job(TransformJobName=name)["TransformJobStatus"]
            if status in ("Completed", "Failed", "Stopped"):
                terminal = True
                if status != "Completed":
                    raise RuntimeError(f"Transform {status}; baseline unchanged")
                # Only completed inference promotes the approved training baseline used for drift.
                model_uri = package["InferenceSpecification"]["Containers"][0]["ModelDataUrl"]
                u = urlparse(model_uri)
                if u.scheme != "s3" or u.netloc != bucket or not u.path.startswith("/ml/"):
                    raise ValueError("Approved model artifact must belong to this project")
                data_bytes = s3.get_object(Bucket=u.netloc, Key=u.path.lstrip("/"))["Body"].read(1048577)
                if len(data_bytes) > 1048576:
                    raise ValueError("Unexpected model artifact size")
                with tarfile.open(fileobj=BytesIO(data_bytes), mode="r:gz") as archive:
                    member = archive.getmember("model.json")
                    if not member.isfile() or member.size > 1048576:
                        raise ValueError("Invalid baseline member")
                    baseline = json.load(archive.extractfile(member))
                s3.put_object(Bucket=bucket, Key="ml/baseline/approved.json", Body=json.dumps(baseline).encode())
                return {"job": name, "status": status, "output": output}
            time.sleep(10)
        sm.stop_transform_job(TransformJobName=name)
        raise TimeoutError(f"Deadline exceeded; StopTransformJob requested for {name}. Verify terminal state before teardown.")
    finally:
        if terminal or not created:
            sm.delete_model(ModelName=name)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for key in ("package", "role", "input", "output", "bucket"):
        p.add_argument("--" + key, required=True)
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--max-seconds", type=int, default=900)
    a = p.parse_args()
    import boto3
    print(json.dumps(run(boto3.client("sagemaker", region_name=a.region), boto3.client("s3", region_name=a.region),
                         a.package, a.role, a.input, a.output, a.bucket, a.max_seconds)))
