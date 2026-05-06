import os
import sys
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

# [FIX] Windows console encoding — tránh crash khi in emoji
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

import math
import pandas as pd
import numpy as np
import tensorflow as tf
import keras
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification
from sklearn.model_selection import train_test_split
from sklearn.utils import class_weight

# Bản vá sửa lỗi tương thích Keras 2.10
if not hasattr(keras.utils, "unpack_x_y_sample_weight"):
    try:
        from keras.engine import data_adapter
        keras.utils.unpack_x_y_sample_weight = data_adapter.unpack_x_y_sample_weight
    except ImportError:
        pass

tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

# ============================================================
# GPU SETUP — Smart Growth + Mixed Precision
# ============================================================
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("[GPU] VRAM: Smart Growth ENABLED")
    except RuntimeError as e:
        print(f"[GPU] Warning: {e}")
    try:
        tf.keras.mixed_precision.set_global_policy('mixed_float16')
        print("[GPU] Mixed Precision: ENABLED (Speed x2)")
    except Exception:
        pass
else:
    print("[WARN] No GPU detected - Running on CPU")

print("="*80)
print("  STAGE 33: REDUCE FALSE POSITIVES + FULL COVERAGE")
print("  TARGET: Reduce FPR <= 25%, Raise SAFE Acc >= 70%, Keep Scam Recall >= 75%")
print("  STRATEGY: 4-layer unfreeze, Label Smoothing 0.15, BOOST_MAP rebalance")
print("="*80)

# ============================================================
# PATHS
# ============================================================
DATA_PATH = "stage33.csv"
STAGE32_PATH = "stage32.csv"
REPLAY_PATH = "stage23_master_replay.csv"
STAGE31_PATH = "stage31.csv"
MODEL_LOAD_PATH = "checkpoint_stage32_Final"
MODEL_SAVE_PATH = "checkpoint_stage33_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 128
BATCH_SIZE = 16
EPOCHS = 150
INITIAL_LR = 5e-6      
MIN_LR = 1e-8          
WARMUP_EPOCHS = 5      
NUM_LABELS = 23
GRAD_CLIP_NORM = 1.0   
SEED = 33

if not os.path.exists(DATA_PATH):
    print(f"[ERROR] Khong tim thay {DATA_PATH}")
    exit(1)

# ============================================================
# LOAD DATA
# ============================================================
def safe_load_csv(path, name=""):
    """Load CSV an toan, xu ly label float/NaN/duplicates."""
    if not os.path.exists(path):
        print(f"[WARN] Khong tim thay {path}")
        return pd.DataFrame(columns=['text', 'label'])
    
    df = pd.read_csv(path, encoding='utf-8-sig')
    df = df.dropna(subset=['text', 'label'])
    df['label'] = pd.to_numeric(df['label'], errors='coerce')
    df = df.dropna(subset=['label'])
    df['label'] = df['label'].astype(int)
    df['text'] = df['text'].astype(str)
    df = df[df['text'].str.strip().str.len() > 3]
    if name:
        print(f"[DATA] {name}: {len(df)} mau")
    return df

def stratified_sample(df, max_per_label, seed=33):
    """Lay toi da max_per_label mau/nhan."""
    parts = []
    for label in range(NUM_LABELS):
        label_data = df[df['label'] == label]
        if len(label_data) > 0:
            n = min(max_per_label, len(label_data))
            parts.append(label_data.sample(n=n, random_state=seed))
    return pd.concat(parts, ignore_index=True) if parts else pd.DataFrame(columns=['text', 'label'])

# 1. Du lieu Stage 33
df_new = safe_load_csv(DATA_PATH, "Stage 33 data")

# 2. Replay Stage 32 — [CONFIRMED] Toan bo stage32 (421 mau)
df_replay_s32 = safe_load_csv(STAGE32_PATH, "Stage 32 (Full Replay)")

# 3. Replay tu master (stage 23) — 80 mau/nhan
df_replay_master = pd.DataFrame(columns=['text', 'label'])
if os.path.exists(REPLAY_PATH):
    df_replay_raw = safe_load_csv(REPLAY_PATH)
    df_replay_master = stratified_sample(df_replay_raw, max_per_label=80, seed=SEED)
    print(f"[REPLAY] Master: {len(df_replay_master)} mau")

# 4. Replay tu stage 31 — 40 mau/nhan
df_replay_s31 = pd.DataFrame(columns=['text', 'label'])
if os.path.exists(STAGE31_PATH):
    df_s31_raw = safe_load_csv(STAGE31_PATH)
    df_replay_s31 = stratified_sample(df_s31_raw, max_per_label=40, seed=SEED)
    print(f"[REPLAY] Stage 31: {len(df_replay_s31)} mau")

# Merge tat ca
df = pd.concat([df_new, df_replay_s32, df_replay_master, df_replay_s31], ignore_index=True)

# Loai bo duplicate
before_dedup = len(df)
df = df.drop_duplicates(subset=['text'], keep='first')
removed = before_dedup - len(df)
if removed > 0:
    print(f"[CLEAN] Removed {removed} duplicates")

df = df.sample(frac=1, random_state=SEED).reset_index(drop=True)

texts = df['text'].tolist()
labels = df['label'].tolist()
print(f"\n[TOTAL] {len(df)} mau (new={len(df_new)}, s32={len(df_replay_s32)}, master={len(df_replay_master)}, s31={len(df_replay_s31)})")

# ============================================================
# TRAIN/VAL SPLIT
# ============================================================
label_counts = pd.Series(labels).value_counts()
min_count = label_counts.min()
use_stratify = min_count >= 2

if use_stratify:
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=SEED, stratify=labels
    )
else:
    print(f"[WARN] Mot so nhan co < 2 mau, tat stratify")
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=SEED
    )

# ============================================================
# CLASS WEIGHTS — BOOST_MAP rebalanced
# ============================================================
unique_labels = np.unique(train_labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=train_labels)
cw_dict = {int(label): float(weight) for label, weight in zip(unique_labels, cw_values)}

for i in range(NUM_LABELS):
    if i not in cw_dict:
        cw_dict[i] = 1.0

# [STAGE 33] Rebalanced Boost map
BOOST_MAP = {
    0:  2.0,   # AUTH_POLICE (Giam 3.0 -> 2.0)
    1:  2.5,   # TAX_GOV_APP (Giam 3.5 -> 2.5)
    11: 1.5,   # INVESTMENT (Giam 2.5 -> 1.5)
    17: 2.0,   # DELIVERY_COD (Giu 2.0)
    21: 2.0,   # GENERIC_SCAM (Giam 3.0 -> 2.0)
    22: 2.5,   # SAFE (TANG 1.5 -> 2.5) <- Trong tam giam False Positive
}
for label, multiplier in BOOST_MAP.items():
    if label in cw_dict:
        cw_dict[label] = cw_dict[label] * multiplier

MAX_CLASS_WEIGHT = 10.0
for k in cw_dict:
    cw_dict[k] = min(cw_dict[k], MAX_CLASS_WEIGHT)

train_dist = dict(zip(*np.unique(train_labels, return_counts=True)))
print(f"\n--- Train distribution ({len(train_labels)} mau) ---")
for l in sorted(train_dist.keys()):
    print(f"   Label {l:2d}: {train_dist[l]:4d} | weight={cw_dict[l]:.2f}")
print(f"--- Val: {len(val_labels)} mau ---")

# ============================================================
# TOKENIZE + DATASET PIPELINE
# ============================================================
tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
train_enc = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_enc = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")

train_dataset = (
    tf.data.Dataset.from_tensor_slices((dict(train_enc), train_labels))
    .cache()
    .shuffle(buffer_size=min(len(train_labels), 2000), seed=SEED)
    .batch(BATCH_SIZE)
    .prefetch(tf.data.AUTOTUNE)
)
val_dataset = (
    tf.data.Dataset.from_tensor_slices((dict(val_enc), val_labels))
    .cache()
    .batch(BATCH_SIZE)
    .prefetch(tf.data.AUTOTUNE)
)

# ============================================================
# MODEL — Load Stage 32
# ============================================================
print(f"\n[MODEL] Loading from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# ============================================================
# SELECTIVE FINE-TUNING: Unfreeze 4 lop cuoi (Giam overfit)
# Layer 20, 21, 22, 23
# ============================================================
model.mobilebert.embeddings.trainable = False

for layer in model.mobilebert.encoder.layer[:20]:
    layer.trainable = False

for layer in model.mobilebert.encoder.layer[20:]:
    layer.trainable = True

model.classifier.trainable = True

trainable = sum(int(tf.reduce_prod(v.shape)) for v in model.trainable_variables)
total_params = sum(int(tf.reduce_prod(v.shape)) for v in model.variables)
print(f"[MODEL] Trainable: {trainable:,} / {total_params:,} params ({trainable/total_params*100:.1f}%)")

# ============================================================
# FOCAL LOSS — gamma=2.0, label_smoothing=0.15 (Tang smoothing)
# ============================================================
class FocalLossFromLogits(tf.keras.losses.Loss):
    def __init__(self, gamma=2.0, label_smoothing=0.15, **kwargs):
        super().__init__(**kwargs)
        self.gamma = gamma
        self.label_smoothing = label_smoothing
    
    def call(self, y_true, y_pred):
        y_pred = tf.cast(y_pred, tf.float32)
        y_true = tf.cast(y_true, tf.int32)
        y_true = tf.reshape(y_true, [-1])
        num_classes = tf.shape(y_pred)[-1]
        y_true_onehot = tf.one_hot(y_true, num_classes)
        y_true_smooth = y_true_onehot * (1.0 - self.label_smoothing) + \
                        self.label_smoothing / tf.cast(num_classes, tf.float32)
        probs = tf.nn.softmax(y_pred, axis=-1)
        probs = tf.clip_by_value(probs, 1e-7, 1.0 - 1e-7)
        p_t = tf.reduce_sum(probs * y_true_onehot, axis=-1)
        focal_weight = tf.pow(1.0 - p_t, self.gamma)
        ce = -tf.reduce_sum(y_true_smooth * tf.math.log(probs), axis=-1)
        return tf.reduce_mean(focal_weight * ce)
    
    def get_config(self):
        config = super().get_config()
        config.update({"gamma": self.gamma, "label_smoothing": self.label_smoothing})
        return config

focal_loss = FocalLossFromLogits(gamma=2.0, label_smoothing=0.15)

# LR Schedule
steps_per_epoch = math.ceil(len(train_labels) / BATCH_SIZE)
total_steps = steps_per_epoch * EPOCHS
warmup_steps = steps_per_epoch * WARMUP_EPOCHS

class WarmupCosineDecay(tf.keras.optimizers.schedules.LearningRateSchedule):
    def __init__(self, initial_lr, warmup_steps, total_steps, min_lr=1e-8):
        super().__init__()
        self.initial_lr = initial_lr
        self.warmup_steps = warmup_steps
        self.total_steps = total_steps
        self.min_lr = min_lr
    def __call__(self, step):
        step = tf.cast(step, tf.float32)
        warmup = tf.cast(self.warmup_steps, tf.float32)
        total = tf.cast(self.total_steps, tf.float32)
        warmup_lr = self.initial_lr * (step / tf.maximum(warmup, 1.0))
        progress = (step - warmup) / tf.maximum(total - warmup, 1.0)
        progress = tf.clip_by_value(progress, 0.0, 1.0)
        cosine_lr = self.min_lr + (self.initial_lr - self.min_lr) * 0.5 * (1.0 + tf.cos(np.pi * progress))
        return tf.where(step < warmup, warmup_lr, cosine_lr)
    def get_config(self):
        return {"initial_lr": self.initial_lr, "warmup_steps": self.warmup_steps, "total_steps": self.total_steps, "min_lr": self.min_lr}

lr_schedule = WarmupCosineDecay(INITIAL_LR, warmup_steps, total_steps, MIN_LR)
optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule, clipnorm=GRAD_CLIP_NORM)
model.compile(optimizer=optimizer, loss=focal_loss, metrics=["accuracy"])

# Early Stopping
class SmartEarlyStopping(tf.keras.callbacks.Callback):
    def __init__(self, patience=20, save_path=MODEL_SAVE_PATH):
        super(SmartEarlyStopping, self).__init__()
        self.patience = patience
        self.save_path = save_path
        self.best_acc = -1.0
        self.best_loss = float('inf')
        self.best_epoch = 0
        self.best_weights = None
        self.wait = 0
    def on_train_begin(self, logs=None):
        self.wait = 0
    def on_epoch_end(self, epoch, logs=None):
        val_loss = logs.get('val_loss', float('inf'))
        val_acc = logs.get('val_accuracy', 0.0)
        train_acc = logs.get('accuracy', 0.0)
        try:
            current_lr = float(self.model.optimizer.learning_rate(self.model.optimizer.iterations))
        except Exception:
            current_lr = 0.0
        is_improved = False
        if val_acc > self.best_acc + 1e-5:
            is_improved = True
        elif abs(val_acc - self.best_acc) < 1e-5 and val_loss < self.best_loss - 1e-4:
            is_improved = True
        if self.best_weights is None:
            is_improved = True
        if is_improved:
            self.best_acc = val_acc
            self.best_loss = val_loss
            self.best_epoch = epoch + 1
            self.best_weights = self.model.get_weights()
            self.wait = 0
            self.model.save_pretrained(self.save_path)
            print(f"\n  >>> [BEST] Epoch {epoch+1} | val_acc={val_acc:.4f} val_loss={val_loss:.4f} | train_acc={train_acc:.4f} | lr={current_lr:.2e}")
        else:
            self.wait += 1
            print(f"\n  [{self.wait}/{self.patience}] No improve. Best={self.best_acc:.4f}@ep{self.best_epoch} | lr={current_lr:.2e}")
            if self.wait >= self.patience:
                self.model.stop_training = True
                if self.best_weights is not None:
                    self.model.set_weights(self.best_weights)
    def on_train_end(self, logs=None):
        if self.best_weights is not None:
            self.model.set_weights(self.best_weights)
            self.model.save_pretrained(self.save_path)

early_stop = SmartEarlyStopping(patience=20, save_path=MODEL_SAVE_PATH)

print(f"\n{'='*80}\n  TRAINING STAGE 33...\n{'='*80}")
model.fit(train_dataset, validation_data=val_dataset, epochs=EPOCHS, class_weight=cw_dict, callbacks=[early_stop])

print(f"\n{'='*80}\n  DONE! Best val_accuracy: {early_stop.best_acc:.4f} @ epoch {early_stop.best_epoch}\n  Checkpoint: {MODEL_SAVE_PATH}\n{'='*80}")
