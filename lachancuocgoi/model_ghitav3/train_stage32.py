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
print("  STAGE 32: FIX REGRESSION + UNFREEZE ENCODER")
print("  TARGET: Fix Label 1/0/11 regression, unfreeze 8 encoder layers")
print("  KEY FIX: Trainable params 11K -> ~8M (encoder unfreezing bug)")
print("="*80)

# ============================================================
# PATHS — Load tu checkpoint Stage 31
# ============================================================
DATA_PATH = "stage32.csv"
REPLAY_PATH = "stage23_master_replay.csv"
STAGE31_PATH = "stage31.csv"
STAGE30_PATH = "stage30_rebalance_fix.csv"
MODEL_LOAD_PATH = "checkpoint_stage31_Final"
MODEL_SAVE_PATH = "checkpoint_stage32_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 128
BATCH_SIZE = 16
EPOCHS = 150           # [TUNED] 150 max, early stopping se dung truoc
INITIAL_LR = 5e-6      # [TUNED] Giam tu 2e-5 -> 5e-6 vi gio train 8M params (truoc chi 11K)
MIN_LR = 1e-8          # [TUNED] San thap hon cho cosine decay
WARMUP_EPOCHS = 5      # [TUNED] Warmup ngan hon vi encoder da mature
NUM_LABELS = 23
GRAD_CLIP_NORM = 1.0   # Gradient clipping chong explosion

if not os.path.exists(DATA_PATH):
    print(f"[ERROR] Khong tim thay {DATA_PATH}")
    exit(1)

# ============================================================
# LOAD DATA — Stage 32 + Replay from master + Stage 31 + Stage 30
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
    
    # Loai bo text rong hoac qua ngan
    df = df[df['text'].str.strip().str.len() > 3]
    
    if name:
        print(f"[DATA] {name}: {len(df)} mau")
    return df

def stratified_sample(df, max_per_label, seed=32):
    """Lay toi da max_per_label mau/nhan."""
    parts = []
    for label in range(NUM_LABELS):
        label_data = df[df['label'] == label]
        if len(label_data) > 0:
            n = min(max_per_label, len(label_data))
            parts.append(label_data.sample(n=n, random_state=seed))
    return pd.concat(parts, ignore_index=True) if parts else pd.DataFrame(columns=['text', 'label'])

# 1. Du lieu Stage 32 moi
df_new = safe_load_csv(DATA_PATH, "Stage 32 data")

# 2. Replay tu master (stage 23) — 80 mau/nhan (tang tu 50)
df_replay_master = pd.DataFrame(columns=['text', 'label'])
if os.path.exists(REPLAY_PATH):
    df_replay_raw = safe_load_csv(REPLAY_PATH)
    df_replay_master = stratified_sample(df_replay_raw, max_per_label=80, seed=32)
    replay_counts = df_replay_master['label'].value_counts().sort_index()
    missing = [i for i in range(NUM_LABELS) if i not in replay_counts.index]
    print(f"[REPLAY] Master: {len(df_replay_master)} mau (max 80/nhan)")
    if missing:
        print(f"[WARN] Nhan thieu trong replay master: {missing}")

# 3. Replay tu stage 31 — 40 mau/nhan (tang tu 30)
df_replay_s31 = pd.DataFrame(columns=['text', 'label'])
if os.path.exists(STAGE31_PATH):
    df_s31_raw = safe_load_csv(STAGE31_PATH)
    df_replay_s31 = stratified_sample(df_s31_raw, max_per_label=40, seed=32)
    print(f"[REPLAY] Stage 31: {len(df_replay_s31)} mau (max 40/nhan)")

# 4. Replay tu stage 30 — 30 mau/nhan
df_replay_s30 = pd.DataFrame(columns=['text', 'label'])
if os.path.exists(STAGE30_PATH):
    df_s30_raw = safe_load_csv(STAGE30_PATH)
    df_replay_s30 = stratified_sample(df_s30_raw, max_per_label=30, seed=32)
    print(f"[REPLAY] Stage 30: {len(df_replay_s30)} mau (max 30/nhan)")

# Merge tat ca
df = pd.concat([df_new, df_replay_master, df_replay_s31, df_replay_s30], ignore_index=True)

# Loai bo duplicate text (giu ban dau)
before_dedup = len(df)
df = df.drop_duplicates(subset=['text'], keep='first')
removed = before_dedup - len(df)
if removed > 0:
    print(f"[CLEAN] Removed {removed} duplicates")

df = df.sample(frac=1, random_state=32).reset_index(drop=True)

texts = df['text'].tolist()
labels = df['label'].tolist()
print(f"\n[TOTAL] {len(df)} mau (new={len(df_new)}, master={len(df_replay_master)}, "
      f"s31={len(df_replay_s31)}, s30={len(df_replay_s30)})")

# ============================================================
# TRAIN/VAL SPLIT — Stratified neu du mau
# ============================================================
label_counts = pd.Series(labels).value_counts()
min_count = label_counts.min()
use_stratify = min_count >= 2

if use_stratify:
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=32, stratify=labels
    )
else:
    print(f"[WARN] Mot so nhan co < 2 mau, tat stratify")
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=32
    )

# ============================================================
# CLASS WEIGHTS — auto balanced + boost cho nhan regression
# ============================================================
unique_labels = np.unique(train_labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=train_labels)
cw_dict = {int(label): float(weight) for label, weight in zip(unique_labels, cw_values)}

# Dien day du 23 nhan
for i in range(NUM_LABELS):
    if i not in cw_dict:
        cw_dict[i] = 1.0

# [STAGE 32] Boost map: uu tien fix regression labels
BOOST_MAP = {
    1:  3.5,   # TAX_GOV_APP: regression -27%, can phuc hoi gap
    0:  3.0,   # AUTH_POLICE: regression -15%
    21: 3.0,   # GENERIC_SCAM: chi 12.5%, rat yeu
    11: 2.5,   # INVESTMENT: regression -20%
    17: 2.0,   # DELIVERY_COD: regression -9%
    22: 1.5,   # SAFE: da 63.5%, giam boost de can bang
    7:  1.5,   # DEEPFAKE: da 52.2%, duy tri
    10: 1.5,   # CHARITY: da 73.0%, duy tri
    16: 1.5,   # BANK_FRAUD: da 58.7%, duy tri
    12: 1.5,   # JOB_TASK: da 56.0%, duy tri
    13: 1.0,   # GIFT_LOTTERY: da 81.4%, ko can boost
}
for label, multiplier in BOOST_MAP.items():
    if label in cw_dict:
        cw_dict[label] = cw_dict[label] * multiplier

# Cap class weight toi da 10.0 (on dinh gradient)
MAX_CLASS_WEIGHT = 10.0
for k in cw_dict:
    cw_dict[k] = min(cw_dict[k], MAX_CLASS_WEIGHT)

# In phan bo training
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

# [OPT] Cache + Shuffle + Batch + Prefetch pipeline
train_dataset = (
    tf.data.Dataset.from_tensor_slices((dict(train_enc), train_labels))
    .cache()
    .shuffle(buffer_size=min(len(train_labels), 2000), seed=32)
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
# MODEL — Load tu checkpoint Stage 31
# ============================================================
print(f"\n[MODEL] Loading from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# ============================================================
# [CRITICAL FIX] SELECTIVE FINE-TUNING: Unfreeze 8 lop cuoi DUNG CACH
# 
# BUG Stage 31: model.mobilebert.trainable = False
#   -> Freeze TOAN BO encoder (ke ca sub-layers)
#   -> layer[-8:].trainable = True SAU DO KHONG CO TAC DUNG
#   -> Chi 11,799 params trainable (classifier head only)
#
# FIX Stage 32: Freeze TUNG LAYER RIENG LE, roi unfreeze 8 layer cuoi
#   -> ~8M params trainable (encoder layers 16-23 + classifier)
# ============================================================
# Buoc 1: Freeze embeddings
model.mobilebert.embeddings.trainable = False

# Buoc 2: Freeze TUNG encoder layer rieng le (layers 0-15)
for layer in model.mobilebert.encoder.layer[:16]:
    layer.trainable = False

# Buoc 3: Unfreeze 8 encoder layers cuoi (layers 16-23)
for layer in model.mobilebert.encoder.layer[16:]:
    layer.trainable = True

# Buoc 4: Unfreeze classifier head
model.classifier.trainable = True

trainable = sum(int(tf.reduce_prod(v.shape)) for v in model.trainable_variables)
total_params = sum(int(tf.reduce_prod(v.shape)) for v in model.variables)
print(f"[MODEL] Trainable: {trainable:,} / {total_params:,} params ({trainable/total_params*100:.1f}%)")

# Verify fix worked
if trainable < 100000:
    print(f"[ERROR] Trainable params qua thap ({trainable})! Freeze bug van con!")
    print(f"[DEBUG] Trainable variables:")
    for v in model.trainable_variables:
        print(f"  {v.name}: {v.shape}")
    exit(1)
else:
    print(f"[OK] Encoder unfreezing THANH CONG! {trainable:,} params trainable")

# ============================================================
# FOCAL LOSS — gamma=2.0, label_smoothing=0.1
# [FIX] Cast ve float32 tranh NaN voi mixed_float16
# ============================================================
class FocalLossFromLogits(tf.keras.losses.Loss):
    def __init__(self, gamma=2.0, label_smoothing=0.1, **kwargs):
        super().__init__(**kwargs)
        self.gamma = gamma
        self.label_smoothing = label_smoothing
    
    def call(self, y_true, y_pred):
        # [CRITICAL] Cast ve float32 — mixed_float16 tra logits float16
        y_pred = tf.cast(y_pred, tf.float32)
        
        # [FIX] Flatten y_true an toan, xu ly ca scalar va batch
        y_true = tf.cast(y_true, tf.int32)
        y_true = tf.reshape(y_true, [-1])
        
        num_classes = tf.shape(y_pred)[-1]
        y_true_onehot = tf.one_hot(y_true, num_classes)
        
        # Label smoothing
        y_true_smooth = y_true_onehot * (1.0 - self.label_smoothing) + \
                        self.label_smoothing / tf.cast(num_classes, tf.float32)
        
        # Softmax -> probabilities (float32)
        probs = tf.nn.softmax(y_pred, axis=-1)
        probs = tf.clip_by_value(probs, 1e-7, 1.0 - 1e-7)
        
        # Focal weight: (1 - p_correct)^gamma
        p_t = tf.reduce_sum(probs * y_true_onehot, axis=-1)
        focal_weight = tf.pow(1.0 - p_t, self.gamma)
        
        # Cross entropy voi smoothed labels
        ce = -tf.reduce_sum(y_true_smooth * tf.math.log(probs), axis=-1)
        
        return tf.reduce_mean(focal_weight * ce)
    
    def get_config(self):
        config = super().get_config()
        config.update({"gamma": self.gamma, "label_smoothing": self.label_smoothing})
        return config

focal_loss = FocalLossFromLogits(gamma=2.0, label_smoothing=0.1)

# ============================================================
# WARMUP + COSINE DECAY LR SCHEDULE
# ============================================================
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
        
        # Phase 1: Linear warmup 0 -> initial_lr
        warmup_lr = self.initial_lr * (step / tf.maximum(warmup, 1.0))
        
        # Phase 2: Cosine decay initial_lr -> min_lr
        progress = (step - warmup) / tf.maximum(total - warmup, 1.0)
        progress = tf.clip_by_value(progress, 0.0, 1.0)
        cosine_lr = self.min_lr + (self.initial_lr - self.min_lr) * 0.5 * (1.0 + tf.cos(np.pi * progress))
        
        return tf.where(step < warmup, warmup_lr, cosine_lr)
    
    def get_config(self):
        return {
            "initial_lr": self.initial_lr,
            "warmup_steps": self.warmup_steps,
            "total_steps": self.total_steps,
            "min_lr": self.min_lr,
        }

lr_schedule = WarmupCosineDecay(INITIAL_LR, warmup_steps, total_steps, MIN_LR)

# Adam voi gradient clipping
optimizer = tf.keras.optimizers.Adam(
    learning_rate=lr_schedule,
    clipnorm=GRAD_CLIP_NORM
)

model.compile(optimizer=optimizer, loss=focal_loss, metrics=["accuracy"])
print(f"\n[LOSS] Focal Loss (gamma=2.0, smoothing=0.1)")
print(f"[LR]   0 -> {INITIAL_LR} (warmup {WARMUP_EPOCHS}ep) -> {MIN_LR} (cosine {EPOCHS}ep)")
print(f"[OPT]  Adam + GradClip={GRAD_CLIP_NORM}")

# ============================================================
# SMART EARLY STOPPING — patience=20, save best weights only
# ============================================================
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
            print(f"\n  >>> [BEST] Epoch {epoch+1} | val_acc={val_acc:.4f} val_loss={val_loss:.4f} | "
                  f"train_acc={train_acc:.4f} | lr={current_lr:.2e}")
            print(f"      Saved to {self.save_path}")
        else:
            self.wait += 1
            print(f"\n  [{self.wait}/{self.patience}] No improve. Best={self.best_acc:.4f}@ep{self.best_epoch} | lr={current_lr:.2e}")
            if self.wait >= self.patience:
                self.model.stop_training = True
                print(f"\n  [STOP] Early Stop! Restoring best weights (acc={self.best_acc:.4f} @ epoch {self.best_epoch})")
                if self.best_weights is not None:
                    self.model.set_weights(self.best_weights)
    
    def on_train_end(self, logs=None):
        """Dam bao luon save best weights khi ket thuc training"""
        if self.best_weights is not None:
            self.model.set_weights(self.best_weights)
            self.model.save_pretrained(self.save_path)
            print(f"\n  [FINAL] Restored & saved best weights (acc={self.best_acc:.4f} @ epoch {self.best_epoch})")

early_stop = SmartEarlyStopping(patience=20, save_path=MODEL_SAVE_PATH)

# ============================================================
# TRAINING
# ============================================================
print(f"\n{'='*80}")
print(f"  TRAINING STAGE 32...")
print(f"  Steps/epoch: {steps_per_epoch} | Total steps: {total_steps} | Warmup: {warmup_steps}")
print(f"{'='*80}")

model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    class_weight=cw_dict,
    callbacks=[early_stop]
)

print(f"\n{'='*80}")
print(f"  DONE! Best val_accuracy: {early_stop.best_acc:.4f} @ epoch {early_stop.best_epoch}")
print(f"  Checkpoint saved to: {MODEL_SAVE_PATH}")
print(f"{'='*80}")
