import os
import sys
import copy
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

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

import re

def clean_text(text: str) -> str:
    """TIỀN XỬ LÝ (NORMALIZATION) CỐT LÕI CỦA STAGE 34"""
    if not isinstance(text, str):
        return ""
    text = text.lower()
    text = re.sub(r'[^\w\s]', '', text)
    text = text.replace('_', '')
    text = re.sub(r'\s+', ' ', text).strip()
    return text

if not hasattr(keras.utils, "unpack_x_y_sample_weight"):
    try:
        from keras.engine import data_adapter
        keras.utils.unpack_x_y_sample_weight = data_adapter.unpack_x_y_sample_weight
    except ImportError:
        pass

tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

# ============================================================
# GPU SETUP
# ============================================================
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("[GPU] VRAM: Smart Growth ENABLED")
        tf.keras.mixed_precision.set_global_policy('mixed_float16')
        print("[GPU] Mixed Precision: ENABLED (Speed x2)")
    except RuntimeError as e:
        print(f"[GPU] Warning: {e}")

print("="*80)
print("  STAGE 34: ULTIMATE NORMALIZATION + PERFECT RECALL")
print("  TARGET: Production Ready")
print("="*80)

DATA_PATH = "stage34_master_mix.csv"
MODEL_LOAD_PATH = "checkpoint_stage32_Final"
MODEL_SAVE_PATH = "checkpoint_stage34_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 128
BATCH_SIZE = 16
EPOCHS = 150
INITIAL_LR = 5e-6      
MIN_LR = 1e-8          
WARMUP_EPOCHS = 5      
NUM_LABELS = 23
GRAD_CLIP_NORM = 1.0   
SEED = 34

df_master = pd.read_csv(DATA_PATH, encoding='utf-8-sig')
df_master['text'] = df_master['text'].astype(str).apply(clean_text)
df_master = df_master[df_master['text'].str.strip().str.len() > 3]

# Deduplicate lần cuối nếu còn
df_master = df_master.drop_duplicates(subset=['text'], keep='first')
df_master = df_master.sample(frac=1, random_state=SEED).reset_index(drop=True)

texts = df_master['text'].tolist()
labels = df_master['label'].astype(int).tolist()

label_counts = pd.Series(labels).value_counts()
use_stratify = label_counts.min() >= 2

if use_stratify:
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=SEED, stratify=labels)
else:
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=SEED)

unique_labels = np.unique(train_labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=train_labels)
cw_dict = {int(label): float(weight) for label, weight in zip(unique_labels, cw_values)}

for i in range(NUM_LABELS):
    if i not in cw_dict:
        cw_dict[i] = 1.0

# [STAGE 34] Cân bằng lại SAFE về 2.0 (Thấp hơn Stage 33 là 2.5) để khôi phục Recall Scams.
BOOST_MAP = {
    0:  2.0,   
    1:  2.5,   
    11: 1.5,   
    17: 2.0,   
    21: 2.0,   
    22: 2.0,   # Tối ưu hóa Trade-off (Stage 32 là 1.5, Stage 33 là 2.5) => Lấy điểm giữa là 2.0
}
for label, multiplier in BOOST_MAP.items():
    if label in cw_dict:
        cw_dict[label] = cw_dict[label] * multiplier

MAX_CLASS_WEIGHT = 10.0
for k in cw_dict:
    cw_dict[k] = min(cw_dict[k], MAX_CLASS_WEIGHT)

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
train_enc = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_enc = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")

train_dataset = tf.data.Dataset.from_tensor_slices((dict(train_enc), train_labels)).cache().shuffle(buffer_size=min(len(train_labels), 2000), seed=SEED).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)
val_dataset = tf.data.Dataset.from_tensor_slices((dict(val_enc), val_labels)).cache().batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

print(f"\n[MODEL] Loading from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# Unfreeze lớp top 4
model.mobilebert.embeddings.trainable = False
for layer in model.mobilebert.encoder.layer[:20]:
    layer.trainable = False
for layer in model.mobilebert.encoder.layer[20:]:
    layer.trainable = True
model.classifier.trainable = True

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
            print(f"  >>> [BEST] Epoch {epoch+1} | val_acc={val_acc:.4f} val_loss={val_loss:.4f}")
        else:
            self.wait += 1
            print(f"  [{self.wait}/{self.patience}] No improve. Best={self.best_acc:.4f}")
            if self.wait >= self.patience:
                self.model.stop_training = True
                if self.best_weights is not None:
                    self.model.set_weights(self.best_weights)
    def on_train_end(self, logs=None):
        if self.best_weights is not None:
            self.model.set_weights(self.best_weights)
            self.model.save_pretrained(self.save_path)

early_stop = SmartEarlyStopping(patience=20, save_path=MODEL_SAVE_PATH)

print(f"\n{'='*80}\n  TRAINING STAGE 34...\n{'='*80}")
model.fit(train_dataset, validation_data=val_dataset, epochs=EPOCHS, class_weight=cw_dict, callbacks=[early_stop])

print(f"\n{'='*80}\n  DONE! Best val_accuracy: {early_stop.best_acc:.4f} @ epoch {early_stop.best_epoch}")
print(f"  Checkpoint: {MODEL_SAVE_PATH}")
print("="*80)

# ============================================================
# EXPORT TFLITE AUTOMATICALLY
# ============================================================
print("\n⚙️ BẮT ĐẦU EXPORT RA TFLITE (FLOAT16)...")
try:
    # Set to CPU logic context for converter safety if needed
    with tf.device('/CPU:0'):
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        # Bắt buộc khai báo OpsSet để tránh lỗi khi convert MobileBERT
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS, # Enable TensorFlow Lite ops.
            tf.lite.OpsSet.SELECT_TF_OPS    # Enable TensorFlow ops.
        ]
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        
        tflite_model = converter.convert()
        out_dir = r"ver7(30-33)\34"
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
        
        out_file = os.path.join(out_dir, "ghitav3_stage34.tflite")
        with open(out_file, "wb") as f:
            f.write(tflite_model)
            
        print(f"✅ Đã export thành công ra: {out_file}")
        print(f"📦 Kích thước: {os.path.getsize(out_file) / 1024 / 1024:.1f} MB")
        print("💡 Hãy copy file này vào app/src/main/assets của Android!")
except Exception as e:
    print(f"❌ Có lỗi khi convert TFLite: {e}")
    print("Vui lòng tự chạy file fix_tflite_export.py nếu cần.")
