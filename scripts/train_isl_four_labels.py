import argparse
import json
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split


LABELS = ["BUKHAR", "PET-DARD", "SANS-TAKLEEF", "SAR-DARD", "NO-SIGN"]
WINDOW_SIZE = 30
FEATURE_SIZE = 168


def read_json(path: Path) -> dict:
    for encoding in ("utf-8-sig", "utf-16"):
        try:
            return json.loads(path.read_text(encoding=encoding))
        except UnicodeError:
            continue
    return json.loads(path.read_text())


def load_dataset(dataset_dir: Path):
    label_to_index = {label: index for index, label in enumerate(LABELS)}
    samples = []
    targets = []

    for path in sorted(dataset_dir.glob("*.json")):
        data = read_json(path)
        label = data.get("label")
        if label not in label_to_index:
            continue

        frames = data.get("frames", [])
        if len(frames) < WINDOW_SIZE:
            continue

        features = [frame["features"] for frame in frames[:WINDOW_SIZE]]
        arr = np.asarray(features, dtype=np.float32)
        if arr.shape != (WINDOW_SIZE, FEATURE_SIZE):
            continue

        samples.append(arr)
        targets.append(label_to_index[label])

    if not samples:
        raise RuntimeError(f"No matching samples found in {dataset_dir}")

    y = np.asarray(targets, dtype=np.int64)
    missing = [label for label, index in label_to_index.items() if not (y == index).any()]
    if missing:
        raise RuntimeError(
            "Missing training samples for labels: "
            + ", ".join(missing)
            + ". Collect background/no-sign samples before training this model."
        )

    return np.stack(samples), y


def build_model(num_labels: int) -> tf.keras.Model:
    inputs = tf.keras.Input(shape=(WINDOW_SIZE, FEATURE_SIZE), name="features")
    x = tf.keras.layers.LayerNormalization()(inputs)
    x = tf.keras.layers.Conv1D(48, 3, padding="same", activation="relu")(x)
    x = tf.keras.layers.Dropout(0.15)(x)
    x = tf.keras.layers.GlobalAveragePooling1D()(x)
    x = tf.keras.layers.Dense(48, activation="relu")(x)
    x = tf.keras.layers.Dropout(0.20)(x)
    outputs = tf.keras.layers.Dense(num_labels, activation="softmax")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )
    return model


def convert_tflite(model: tf.keras.Model, representative_x: np.ndarray) -> bytes:
    def representative_dataset():
        for sample in representative_x[:100]:
            yield [sample[np.newaxis, ...].astype(np.float32)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    return converter.convert()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-dir", type=Path, default=Path("exports/isl_dataset"))
    parser.add_argument(
        "--model-out",
        type=Path,
        default=Path("assets/models/isl_lstm_int8.tflite"),
    )
    parser.add_argument("--labels-out", type=Path, default=Path("assets/isl_labels.json"))
    args = parser.parse_args()

    np.random.seed(7)
    tf.keras.utils.set_random_seed(7)

    x, y = load_dataset(args.dataset_dir)
    counts = {label: int((y == i).sum()) for i, label in enumerate(LABELS)}
    print(f"Loaded {len(y)} samples: {counts}")

    x_train, x_test, y_train, y_test = train_test_split(
        x,
        y,
        test_size=0.2,
        random_state=7,
        stratify=y,
    )

    model = build_model(len(LABELS))
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor="val_accuracy",
            patience=25,
            restore_best_weights=True,
        )
    ]
    model.fit(
        x_train,
        y_train,
        validation_split=0.2,
        epochs=180,
        batch_size=16,
        callbacks=callbacks,
        verbose=2,
    )

    loss, acc = model.evaluate(x_test, y_test, verbose=0)
    print(f"Holdout accuracy: {acc:.3f} loss: {loss:.3f}")

    predictions = model.predict(x_test, verbose=0).argmax(axis=1)
    print(confusion_matrix(y_test, predictions))
    print(classification_report(y_test, predictions, target_names=LABELS))

    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    args.labels_out.parent.mkdir(parents=True, exist_ok=True)
    args.model_out.write_bytes(convert_tflite(model, x_train))
    args.labels_out.write_text(
        json.dumps({"labels": LABELS}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {args.model_out}")
    print(f"Wrote {args.labels_out}")


if __name__ == "__main__":
    main()
