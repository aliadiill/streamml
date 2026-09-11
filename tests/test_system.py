import base64
import copy
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock
ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "src"), str(ROOT / "ml"), str(ROOT / "scripts")]
from streamml.core import InvalidEvent, canonical, digest, validate
from streamml.generator import generate
from streamml.ingest import AwsStore, handle, process
from streamml.model import drift, metrics, quality, split, train
from streamml.monitor import should_retrain
from build_pipeline import build
from batch_approved import run


class MemoryStore:
    def __init__(self):
        self.raw, self.ids, self.rows, self.invalid = {}, set(), [], []
        self.fail_once = False
    def put_raw(self, key, data, checksum):
        if key in self.raw and self.raw[key] != data:
            raise InvalidEvent("Conflicting duplicate")
        self.raw[key] = data
    def commit(self, event, checksum):
        if self.fail_once:
            self.fail_once = False
            raise RuntimeError("Injected network failure after S3 write")
        if event["event_id"] in self.ids:
            return "duplicate"
        self.ids.add(event["event_id"])
        self.rows.append(event)
        return "processed"
    def quarantine(self, record_id, reason):
        self.invalid.append((record_id, reason))


def record(event, sequence="1"):
    return {"eventID": "shard:" + sequence, "kinesis": {"sequenceNumber": sequence,
            "data": base64.b64encode(json.dumps(event).encode()).decode()}}


class IngestionTests(unittest.TestCase):
    def setUp(self):
        self.event = next(generate(1))
        self.store = MemoryStore()
    def test_duplicate_counts_once(self):
        self.assertEqual(process(self.event, self.store), "processed")
        self.assertEqual(process(self.event, self.store), "duplicate")
        self.assertEqual(len(self.store.rows), 1)
        self.assertEqual(len(self.store.raw), 1)
    def test_crash_between_s3_and_atomic_commit_recovers(self):
        self.store.fail_once = True
        item = record(self.event)
        self.assertEqual(handle({"Records": [item]}, self.store)["batchItemFailures"], [{"itemIdentifier": "1"}])
        self.assertEqual(len(self.store.raw), 1)
        self.assertEqual(len(self.store.rows), 0)
        self.assertEqual(handle({"Records": [item]}, self.store)["batchItemFailures"], [])
        self.assertEqual(len(self.store.rows), 1)
    def test_changed_payload_same_id_rejected(self):
        process(self.event, self.store)
        conflicting = {**self.event, "amount_cents": self.event["amount_cents"] + 1}
        with self.assertRaises(InvalidEvent):
            process(conflicting, self.store)
    def test_invalid_records_quarantined_without_poisoning_batch(self):
        invalid = {**self.event, "amount_cents": -1}
        result = handle({"Records": [record(invalid), record(self.event, "2")]}, self.store)
        self.assertEqual(result, {"batchItemFailures": []})
        self.assertEqual(len(self.store.invalid), 1)
        self.assertEqual(len(self.store.rows), 1)
    def test_invalid_nonfinite_boolean_and_unknown_schema(self):
        for change in ({"merchant_risk": float("nan")}, {"amount_cents": True}, {"unexpected": "field"},
                       {"occurred_at": "2026-01-01T00:00:00"}, {"online": 2}):
            with self.assertRaises(InvalidEvent):
                validate({**self.event, **change})
    def test_raw_adapter_conditional_write_and_hash_conflict(self):
        class ClientFailure(Exception):
            response = {"Error": {"Code": "PreconditionFailed"}}
        s3 = Mock()
        s3.put_object.side_effect = ClientFailure()
        s3.head_object.return_value = {"Metadata": {"sha256": "different"}}
        store = AwsStore(s3, Mock(), "bucket", "table")
        with self.assertRaises(InvalidEvent):
            store.put_raw(self.event["event_id"], canonical(self.event), digest(self.event))
        self.assertEqual(s3.put_object.call_args.kwargs["IfNoneMatch"], "*")
    def test_ddb_atomic_marker_and_metrics(self):
        ddb = Mock()
        store = AwsStore(Mock(), ddb, "bucket", "table")
        store.commit(validate(self.event), digest(validate(self.event)))
        writes = ddb.transact_write_items.call_args.kwargs["TransactItems"]
        self.assertEqual(writes[0]["Put"]["ConditionExpression"], "attribute_not_exists(pk)")
        self.assertIn("Update", writes[1])
        self.assertIn("payload", writes[2]["Put"]["Item"])


class ModelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = list(generate(1800))
        cls.training, cls.validation, cls.test = split(cls.rows)
        cls.model = train(cls.training, cls.validation)
    def test_generator_reproducible_bounded(self):
        self.assertEqual(list(generate(20)), list(generate(20)))
        with self.assertRaises(ValueError):
            list(generate(10001))
    def test_chronological_disjoint_split_and_duplicate_removal(self):
        parts = split(self.rows + [self.rows[0]])
        ids = [set(r["event_id"] for r in rows) for rows in parts]
        self.assertFalse(ids[0] & ids[1] or ids[1] & ids[2] or ids[0] & ids[2])
        self.assertLess(max(r["occurred_at"] for r in parts[0]), min(r["occurred_at"] for r in parts[1]))
        self.assertLess(max(r["occurred_at"] for r in parts[1]), min(r["occurred_at"] for r in parts[2]))
        self.assertEqual(sum(map(len, parts)), len(self.rows))
    def test_no_labels_or_card_identity_in_features(self):
        self.assertNotIn("fraud_label", self.model["features"])
        self.assertNotIn("card_id", self.model["features"])
        self.assertEqual(self.model["training_rows"], len(self.training))
    def test_holdout_mutation_cannot_influence_training(self):
        # Train consumes no held-out parameter; mutate held-out values and compare reproducibility.
        changed = copy.deepcopy(self.test)
        changed[0]["amount_cents"] = 10000000
        self.assertEqual(self.model, train(self.training, self.validation))
    def test_quality_gate_accepts_good_and_rejects_bad_or_unsupported(self):
        report = metrics(self.test, self.model)
        self.assertTrue(quality(report), report)
        self.assertFalse(quality({**report, "f1": .79}))
        self.assertFalse(quality({**report, "recall": .69}))
        self.assertFalse(quality({**report, "false_positive_rate": .11}))
        self.assertFalse(quality({**report, "positives": 4}))
    def test_controlled_drift_requires_volume_enabled_and_two_breaches(self):
        report = drift([{**r, "merchant_risk": 1} for r in self.test], self.model)
        self.assertGreater(report["score"], .75)
        self.assertFalse(should_retrain(report, False, 2))
        self.assertFalse(should_retrain(report, True, 0))
        self.assertTrue(should_retrain(report, True, 1))
        self.assertFalse(drift(self.test[:20], self.model)["eligible"])


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.pipeline = build("arn:aws:iam::123456789012:role/test", "123456789012.dkr.ecr.us-east-1.amazonaws.com/test:sha",
                              "example-lake", "streamml-dev")
    def test_actual_pipeline_steps_and_manual_gate(self):
        self.assertEqual([s["Type"] for s in self.pipeline["Steps"]], ["Processing", "Training", "Processing", "Condition"])
        gate = self.pipeline["Steps"][-1]["Arguments"]
        self.assertEqual(len(gate["Conditions"]), 6)
        self.assertEqual(gate["IfSteps"][0]["Arguments"]["ModelApprovalStatus"], "PendingManualApproval")
        self.assertEqual(gate["ElseSteps"][0]["Type"], "Fail")
        self.assertNotIn("Transform", json.dumps(self.pipeline["Steps"][:-1]))
    def test_job_argument_shapes_against_botocore(self):
        try:
            from botocore.session import Session
            from botocore.validate import validate_parameters
        except ImportError:
            self.skipTest("Optional botocore API-shape validation requires requirements.txt")
        service = Session().get_service_model("sagemaker")
        def resolve(value):
            if isinstance(value, dict):
                if "Get" in value or "Std:Join" in value:
                    return "s3://example-lake/data/"
                return {k: resolve(v) for k, v in value.items()}
            if isinstance(value, list):
                return [resolve(v) for v in value]
            return value
        for step, operation, name in [(self.pipeline["Steps"][0], "CreateProcessingJob", "ProcessingJobName"),
                                      (self.pipeline["Steps"][1], "CreateTrainingJob", "TrainingJobName"),
                                      (self.pipeline["Steps"][2], "CreateProcessingJob", "ProcessingJobName")]:
            arguments = resolve(step["Arguments"])
            arguments[name] = "streamml-test"
            validate_parameters(arguments, service.operation_model(operation).input_shape)
        register = resolve(self.pipeline["Steps"][-1]["Arguments"]["IfSteps"][0]["Arguments"])
        validate_parameters(register, service.operation_model("CreateModelPackage").input_shape)
    def test_unapproved_model_cannot_create_inference_resources(self):
        sm, s3 = Mock(), Mock()
        sm.describe_model_package.return_value = {"ModelApprovalStatus": "PendingManualApproval"}
        with self.assertRaises(ValueError):
            run(sm, s3, "arn", "role", "s3://lake/ml/input.jsonl", "s3://lake/ml/output", "lake")
        sm.create_model.assert_not_called()


if __name__ == "__main__":
    unittest.main()

