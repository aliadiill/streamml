"""Small deterministic logistic-regression baseline; standard library only."""
import math
import statistics

FEATURES = ["log_amount", "log_distance", "attempts_1h", "merchant_risk", "online"]


def features(row):
    return [math.log1p(row["amount_cents"]), math.log1p(row["distance_km"]),
            float(row["attempts_1h"]), float(row["merchant_risk"]), float(row["online"])]


def sigmoid(value):
    return 1 / (1 + math.exp(-max(-35, min(35, value))))


def predict(model, row):
    x = [(v - m) / s for v, m, s in zip(features(row), model["means"], model["scales"])]
    return sigmoid(model["bias"] + sum(w * v for w, v in zip(model["weights"], x)))


def metrics(rows, model, threshold=None):
    threshold = model.get("threshold", .5) if threshold is None else threshold
    tp = fp = fn = tn = 0
    for row in rows:
        y, p = row["fraud_label"], predict(model, row) >= threshold
        tp += int(y == 1 and p)
        fp += int(y == 0 and p)
        fn += int(y == 1 and not p)
        tn += int(y == 0 and not p)
    precision = tp / max(1, tp + fp)
    recall = tp / max(1, tp + fn)
    return {"f1": 2 * precision * recall / max(1e-12, precision + recall),
            "precision": precision, "recall": recall, "false_positive_rate": fp / max(1, fp + tn),
            "positives": tp + fn, "negatives": fp + tn, "samples": len(rows),
            "true_positives": tp, "false_positives": fp, "false_negatives": fn, "true_negatives": tn}


def train(rows, validation, epochs=220):
    if len(rows) < 100 or len({r["fraud_label"] for r in rows}) != 2:
        raise ValueError("Training requires >=100 records and both classes")
    xs = [features(r) for r in rows]
    means = [statistics.mean(c) for c in zip(*xs)]
    scales = [max(statistics.pstdev(c), .001) for c in zip(*xs)]
    xs = [[(v - m) / s for v, m, s in zip(x, means, scales)] for x in xs]
    weights, bias = [0.0] * len(FEATURES), 0.0
    # Full-batch descent, fixed initialization and order; no nondeterministic dependencies.
    for _ in range(epochs):
        gradients, gb = [0.0] * len(weights), 0.0
        for x, row in zip(xs, rows):
            error = sigmoid(bias + sum(w * v for w, v in zip(weights, x))) - row["fraud_label"]
            gb += error
            for j, value in enumerate(x):
                gradients[j] += error * value
        weights = [w - .15 * (g / len(rows) + .002 * w) for w, g in zip(weights, gradients)]
        bias -= .15 * gb / len(rows)
    model = {"version": 1, "features": FEATURES, "means": means, "scales": scales,
             "weights": weights, "bias": bias, "training_rows": len(rows)}
    # Select operating threshold on validation only. The test set remains untouched.
    model["threshold"] = max([i / 100 for i in range(15, 81, 5)],
                             key=lambda t: metrics(validation, model, t)["f1"])
    return model


def quality(report):
    return (report["samples"] >= 100 and report["positives"] >= 5 and report["negatives"] >= 5
            and report["f1"] >= .80 and report["recall"] >= .70 and report["false_positive_rate"] <= .10)


def split(rows):
    """Chronological split after deduplicating IDs, never shuffle across time."""
    unique = {}
    for row in rows:
        if row["event_id"] in unique and unique[row["event_id"]] != row:
            raise ValueError("Conflicting duplicate ID")
        unique[row["event_id"]] = row
    ordered = sorted(unique.values(), key=lambda r: (r["occurred_at"], r["event_id"]))
    if len(ordered) < 500:
        raise ValueError("At least 500 unique rows required")
    # Group equal timestamps at the same side of the boundary.
    t1, t2 = ordered[int(.6 * len(ordered))]["occurred_at"], ordered[int(.8 * len(ordered))]["occurred_at"]
    train_rows = [r for r in ordered if r["occurred_at"] < t1]
    validation = [r for r in ordered if t1 <= r["occurred_at"] < t2]
    test = [r for r in ordered if r["occurred_at"] >= t2]
    if min(len(train_rows), len(validation), len(test)) < 100:
        raise ValueError("Insufficient distinct timestamps for a chronological split")
    return train_rows, validation, test


def drift(rows, model):
    if len(rows) < 100:
        return {"eligible": False, "reason": "fewer than 100 records", "score": 0}
    columns = list(zip(*(features(row) for row in rows)))
    shifts = {name: abs(statistics.mean(col) - mean) / scale
              for name, col, mean, scale in zip(FEATURES, columns, model["means"], model["scales"])}
    return {"eligible": True, "score": max(shifts.values()), "feature_mean_shift": shifts}

