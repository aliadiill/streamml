"""Compile a real SageMaker DAG without credentials, SDK side effects, or AWS calls."""
import argparse
import json
from pathlib import Path


def get(path):
    return {"Get": path}


def build(role, image, bucket, group, prefix="streamml"):
    def destination(part):
        return {"Std:Join": {"On": "/", "Values": [f"s3://{bucket}/ml/runs",
                            get("Execution.PipelineExecutionId"), part]}}
    def processing(name, mode, inputs, outputs):
        return {"Name": name, "Type": "Processing", "Arguments": {
            "RoleArn": role,
            "AppSpecification": {"ImageUri": image, "ContainerEntrypoint": ["python3", "/opt/program/job.py", mode]},
            "ProcessingResources": {"ClusterConfig": {"InstanceCount": 1, "InstanceType": "ml.m5.large", "VolumeSizeInGB": 10}},
            "StoppingCondition": {"MaxRuntimeInSeconds": 600},
            "NetworkConfig": {"EnableNetworkIsolation": True},
            "ProcessingInputs": [{"InputName": key, "S3Input": {"S3Uri": uri,
                                  "LocalPath": f"/opt/ml/processing/input/{key}", "S3DataType": "S3Prefix",
                                  "S3InputMode": "File", "S3DataDistributionType": "FullyReplicated"}} for key, uri in inputs],
            "ProcessingOutputConfig": {"Outputs": [{"OutputName": key, "S3Output": {
                "S3Uri": destination(key), "LocalPath": f"/opt/ml/processing/output/{key}", "S3UploadMode": "EndOfJob"}} for key in outputs]}
        }}
    preprocess = processing("Preprocess", "preprocess", [("data", get("Parameters.TrainingDataUri"))],
                            ["train", "validation", "test"])
    output = lambda name: get(f"Steps.Preprocess.ProcessingOutputConfig.Outputs['{name}'].S3Output.S3Uri")
    training = {"Name": "Train", "Type": "Training", "Arguments": {
        "RoleArn": role, "AlgorithmSpecification": {"TrainingImage": image, "TrainingInputMode": "File",
                      "ContainerEntrypoint": ["python3", "/opt/program/job.py"], "ContainerArguments": ["train"]},
        "InputDataConfig": [{"ChannelName": name, "DataSource": {"S3DataSource": {
            "S3DataType": "S3Prefix", "S3Uri": output(name), "S3DataDistributionType": "FullyReplicated"}}}
                           for name in ("train", "validation")],
        "OutputDataConfig": {"S3OutputPath": destination("model")},
        "ResourceConfig": {"InstanceCount": 1, "InstanceType": "ml.m5.large", "VolumeSizeInGB": 10},
        "StoppingCondition": {"MaxRuntimeInSeconds": 600},
        "EnableNetworkIsolation": True}}
    evaluation = processing("Evaluate", "evaluate", [("test", output("test")),
                            ("model", get("Steps.Train.ModelArtifacts.S3ModelArtifacts"))], ["evaluation"])
    evaluation["PropertyFiles"] = [{"PropertyFileName": "Report", "OutputName": "evaluation", "FilePath": "evaluation.json"}]
    def value(metric):
        return {"Std:JsonGet": {"PropertyFile": get("Steps.Evaluate.PropertyFiles.Report"), "Path": metric}}
    gates = [("GreaterThanOrEqualTo", "f1", .8), ("GreaterThanOrEqualTo", "recall", .7),
             ("LessThanOrEqualTo", "false_positive_rate", .1), ("GreaterThanOrEqualTo", "samples", 100),
             ("GreaterThanOrEqualTo", "positives", 5), ("GreaterThanOrEqualTo", "negatives", 5)]
    register = {"Name": "RegisterCandidate", "Type": "RegisterModel", "Arguments": {
        "ModelPackageGroupName": group, "ModelApprovalStatus": "PendingManualApproval",
        "ModelPackageDescription": "Chronological holdout gate passed; human approval required before inference.",
        "InferenceSpecification": {"Containers": [{"Image": image, "ModelDataUrl": get("Steps.Train.ModelArtifacts.S3ModelArtifacts")}],
            "SupportedContentTypes": ["application/jsonlines"], "SupportedResponseMIMETypes": ["application/jsonlines"],
            "SupportedTransformInstanceTypes": ["ml.m5.large"]}}}
    condition = {"Name": "QualityGate", "Type": "Condition", "Arguments": {
        "Conditions": [{"Type": op, "LeftValue": value(metric), "RightValue": threshold} for op, metric, threshold in gates],
        "IfSteps": [register], "ElseSteps": [{"Name": "RejectModel", "Type": "Fail",
                            "Arguments": {"ErrorMessage": "Held-out quality gate failed; known model remains unchanged."}}]}}
    return {"Version": "2020-12-01", "Metadata": {"project": prefix}, "Parameters": [
        {"Name": "TrainingDataUri", "Type": "String", "DefaultValue": f"s3://{bucket}/raw/events/"}],
        "Steps": [preprocess, training, evaluation, condition]}


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    for name in ("role", "image", "bucket", "group"):
        p.add_argument("--" + name, required=True)
    p.add_argument("--output", default="build/pipeline.json")
    a = p.parse_args()
    path = Path(a.output)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(build(a.role, a.image, a.bucket, a.group), indent=2))
