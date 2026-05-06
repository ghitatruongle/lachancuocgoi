import os
import tensorflow as tf
from transformers import TFAutoModelForSequenceClassification

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

print("Loading checkpoint...")
model = TFAutoModelForSequenceClassification.from_pretrained('checkpoint_stage34_Final')

print("Exporting to TFLite (no Flex Ops)...")
converter = tf.lite.TFLiteConverter.from_keras_model(model)

converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS]
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]

try:
    tflite_model = converter.convert()
    out_dir = r"ver7(30-34)\34"
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
        
    out_file = os.path.join(out_dir, "ghitav3.tflite")
    with open(out_file, "wb") as f:
        f.write(tflite_model)
        
    print(f"SUCCESS! Exported model without FLEX-OPS to {out_file}")
    print(f"Size: {os.path.getsize(out_file)} Bytes")
except Exception as e:
    print("FAILED:", e)
