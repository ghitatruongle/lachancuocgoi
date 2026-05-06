import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import numpy as np
import pandas as pd
import tensorflow as tf
import keras
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification
from sklearn.utils import class_weight

# --- PATCH FOR TF 2.10 + TRANSFORMERS 4.44+ COMPATIBILITY ---
if not hasattr(keras.utils, "unpack_x_y_sample_weight"):
    try:
        from keras.engine import data_adapter
        keras.utils.unpack_x_y_sample_weight = data_adapter.unpack_x_y_sample_weight
    except Exception:
        pass
# -------------------------------------------------------------

# 1. CẤU HÌNH PHẦN CỨNG (GPU 6GB)
tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=6144)])
        print("🎮 GPU VRAM: Locked at 6GB")
    except RuntimeError as e:
        print(e)

if gpus:
    try:
        tf.keras.mixed_precision.set_global_policy('mixed_float16')
        print("⚡ Mixed Precision: ENABLED (Speed x2)")
    except Exception:
        pass
else:
    print("⚠️ No GPU detected — Running on CPU (slower)")

print("="*80)
print("🛡️ STAGE 24: BANKING & SOCIAL INSURANCE RESCUE 🛡️")
print("TARGET: FIX WEAKNESS IN LABEL 4 (BANK), 5 (BHXH) & 22 (SAFE)")
print("="*80)

# 2. THÔNG SỐ
DATA_PATH = "stage24_scenarios_hard_negative_adv.csv"
MODEL_LOAD_PATH = "checkpoint_stage23_Final"
MODEL_SAVE_PATH = "checkpoint_stage24_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 256
BATCH_SIZE = 16
EPOCHS = 30 # Tối ưu hóa: Tăng epoch, để chế độ Early Stopping tự ngắt
LEARNING_RATE = 2e-5
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Missing: {DATA_PATH}")
    exit(1)
if not os.path.exists(MODEL_LOAD_PATH):
    print(f"❌ Missing checkpoint: {MODEL_LOAD_PATH}")
    exit(1)

# 3. PIPELINE DỮ LIỆU
df = pd.read_csv(DATA_PATH)
df = df.dropna(subset=['text', 'label'])
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()

unique_labels = np.unique(labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=labels)
cw_dict = {int(label): weight for label, weight in zip(unique_labels, cw_values)}

# Keras requires class_weight to have ALL keys from 0 to NUM_LABELS-1
for i in range(NUM_LABELS):
    if i not in cw_dict:
        cw_dict[i] = 1.0

# ĐẶT TRỌNG SỐ TUYỆT ĐỐI (Boost) cho các nhãn yếu nhất
cw_dict[4] = 3.0 # Ngân hàng
cw_dict[5] = 3.0 # BHXH
cw_dict[22] = 2.0 # An toàn (Vì đã có nhiều data nên hạ xuống 2.0)
print(f"💡 Class Weights BOOSTED -> L4(Bank): {cw_dict[4]}, L5(BHXH): {cw_dict[5]}, L22(Safe): {cw_dict[22]}")
print(f"📊 Label distribution: {dict(zip(*np.unique(labels, return_counts=True)))}")

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
inputs = tokenizer(texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")

val_split = 0.2
num_val = int(len(texts) * val_split)

full_dataset = tf.data.Dataset.from_tensor_slices((dict(inputs), labels)).shuffle(3000)
val_dataset = full_dataset.take(num_val).batch(BATCH_SIZE)
train_dataset = full_dataset.skip(num_val).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

# 4. LOAD MODEL TỪ STAGE 23 (Dùng AutoModel chuẩn, tương thích mọi phiên bản transformers)
print(f"🧠 Loading brain from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# Đóng băng backbone, chỉ train classifier head
model.layers[0].trainable = False
print("🔒 Backbone FROZEN — Only classifier head will be trained")

# 5. COMPILE & CALLBACKS
optimizer = tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])

callbacks = [
    tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=5, restore_best_weights=True, verbose=1),
    tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=2, min_lr=1e-6, verbose=1)
]

# 6. TRAIN
print("\n🔥 Bắt đầu huấn luyện Stage 24...")
model.fit(
    train_dataset, 
    validation_data=val_dataset,
    epochs=EPOCHS, 
    class_weight=cw_dict,
    callbacks=callbacks
)

# 7. SAVE (dùng save_pretrained chuẩn HuggingFace)
model.save_pretrained(MODEL_SAVE_PATH)
print(f"✅ Saved checkpoint to {MODEL_SAVE_PATH}")
