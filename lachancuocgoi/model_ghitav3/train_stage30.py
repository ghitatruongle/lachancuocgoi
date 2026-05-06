import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
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
    from keras.engine import data_adapter
    keras.utils.unpack_x_y_sample_weight = data_adapter.unpack_x_y_sample_weight

tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("🎮 GPU VRAM: Smart Growth ENABLED")
    except RuntimeError as e:
        print(e)
if gpus:
    try:
        tf.keras.mixed_precision.set_global_policy('mixed_float16')
        print("⚡ Mixed Precision: ENABLED (Speed x2)")
    except Exception:
        pass
else:
    print("⚠️ No GPU detected — Running on CPU")

print("="*80)
print("🔧 STAGE 30: ULTIMATE REBALANCE (Focal Loss + Stratified Replay) 🔧")
print("TARGET: Fix Label 22 False Positive + Weak Labels 5, 4, 18")
print("="*80)

DATA_PATH = "stage30_rebalance_fix.csv"
REPLAY_PATH = "stage23_master_replay.csv"
MODEL_LOAD_PATH = "checkpoint_stage29_Final"
MODEL_SAVE_PATH = "checkpoint_stage30_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 50
BATCH_SIZE = 16
EPOCHS = 60
INITIAL_LR = 1e-5     # Peak LR sau warmup
WARMUP_EPOCHS = 3      # 3 epoch warmup tuyến tính
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Không tìm thấy {DATA_PATH}"); exit(1)

# ============================================================
# [UPGRADE 1] STRATIFIED REPLAY BUFFER - Đảm bảo đủ 23 nhãn
# Chiến lược: lấy max 40 mẫu/nhãn từ replay, đảm bảo coverage
# ============================================================
df_new = pd.read_csv(DATA_PATH, encoding='utf-8-sig').dropna(subset=['text', 'label'])
df_new['label'] = pd.to_numeric(df_new['label'], errors='coerce').dropna().astype(int)
df_new = df_new.dropna(subset=['label'])
df_new['label'] = df_new['label'].astype(int)
print(f"📦 Dữ liệu mới: {len(df_new)} mẫu")

df_old = pd.DataFrame()
if os.path.exists(REPLAY_PATH):
    df_old_raw = pd.read_csv(REPLAY_PATH, encoding='utf-8-sig').dropna(subset=['text', 'label'])
    # [FIX] Replay CSV có label dạng float "22.0" → convert an toàn
    df_old_raw['label'] = pd.to_numeric(df_old_raw['label'], errors='coerce')
    df_old_raw = df_old_raw.dropna(subset=['label'])
    df_old_raw['label'] = df_old_raw['label'].astype(int)
    
    # Stratified sampling: TỐI ĐA 40 mẫu/nhãn
    replay_parts = []
    for label in range(NUM_LABELS):
        label_data = df_old_raw[df_old_raw['label'] == label]
        if len(label_data) > 0:
            n_sample = min(40, len(label_data))
            replay_parts.append(label_data.sample(n=n_sample, random_state=42))
    
    if replay_parts:
        df_old = pd.concat(replay_parts, ignore_index=True)
        print(f"🔄 Stratified Replay: {len(df_old)} mẫu (max 40/nhãn × {NUM_LABELS} nhãn)")
        replay_counts = df_old['label'].value_counts().sort_index()
        missing = [i for i in range(NUM_LABELS) if i not in replay_counts.index]
        if missing:
            print(f"⚠️ Nhãn thiếu trong replay: {missing}")
else:
    print(f"⚠️ Không tìm thấy {REPLAY_PATH}")

df = pd.concat([df_new, df_old], ignore_index=True)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()
print(f"📊 Tổng dữ liệu: {len(df)} mẫu (new={len(df_new)}, replay={len(df_old)})")

# [FIX] Kiểm tra mỗi nhãn có đủ >= 2 mẫu để stratify
label_counts = pd.Series(labels).value_counts()
min_count = label_counts.min()
if min_count < 2:
    print(f"⚠️ Một số nhãn có < 2 mẫu, tắt stratify cho an toàn")
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=42
    )
else:
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=42, stratify=labels
    )

# Class Weights tự động + boost cho nhãn yếu
unique_labels = np.unique(train_labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=train_labels)
cw_dict = {int(label): weight for label, weight in zip(unique_labels, cw_values)}
for i in range(NUM_LABELS):
    if i not in cw_dict: cw_dict[i] = 1.0

# [CRITICAL] Boost đặc biệt cho nhãn yếu nhất
if 22 in cw_dict: cw_dict[22] = cw_dict[22] * 3.0   # False Positive CRITICAL
if 5 in cw_dict:  cw_dict[5]  = cw_dict[5]  * 2.5   # BHXH rất yếu
if 4 in cw_dict:  cw_dict[4]  = cw_dict[4]  * 2.0   # Ngân hàng yếu
if 18 in cw_dict: cw_dict[18] = cw_dict[18] * 2.0   # Trúng thưởng regression
# Cap class weight tối đa 15.0 để tránh gradient explosion
for k in cw_dict:
    cw_dict[k] = min(cw_dict[k], 15.0)

# In phân bố training
train_dist = dict(zip(*np.unique(train_labels, return_counts=True)))
print(f"\n📊 Train distribution ({len(train_labels)} mẫu):")
for l in sorted(train_dist.keys()):
    print(f"   Label {l:2d}: {train_dist[l]:4d} | weight={cw_dict[l]:.2f}")

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
train_enc = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_enc = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")

train_dataset = tf.data.Dataset.from_tensor_slices((dict(train_enc), train_labels)).shuffle(500).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)
val_dataset = tf.data.Dataset.from_tensor_slices((dict(val_enc), val_labels)).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

print(f"\n🧠 Loading brain from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# ============================================================
# [UPGRADE 2] SELECTIVE FINE-TUNING: 8 lớp cuối
# ============================================================
model.mobilebert.trainable = False
for layer in model.mobilebert.encoder.layer[-8:]:
    layer.trainable = True
model.classifier.trainable = True

trainable = sum(int(tf.reduce_prod(v.shape)) for v in model.trainable_variables)
total_params = sum(int(tf.reduce_prod(v.shape)) for v in model.variables)
print(f"🔓 Trainable: {trainable:,} / {total_params:,} params ({trainable/total_params*100:.1f}%)")

# ============================================================
# [UPGRADE 3] FOCAL LOSS - Focus vào hard examples
# [FIX] Cast về float32 tránh NaN với mixed_float16
# ============================================================
class FocalLossFromLogits(tf.keras.losses.Loss):
    """Focal Loss: downweight easy examples, focus on hard misclassifications.
    gamma=2.0: mẫu dễ (confidence > 0.9) focal_weight ≈ 0.01 → gần như bỏ qua
    label_smoothing=0.1: chống overconfident predictions
    """
    def __init__(self, gamma=2.0, label_smoothing=0.1, **kwargs):
        super().__init__(**kwargs)
        self.gamma = gamma
        self.label_smoothing = label_smoothing
    
    def call(self, y_true, y_pred):
        # [CRITICAL] Cast về float32 — mixed_float16 trả logits float16
        # mà log(float16) rất dễ tràn số → NaN
        y_pred = tf.cast(y_pred, tf.float32)
        y_true = tf.cast(tf.squeeze(y_true), tf.int32)
        
        num_classes = tf.shape(y_pred)[-1]
        y_true_onehot = tf.one_hot(y_true, num_classes)
        
        # Label smoothing: [0,0,1,0] → [0.004, 0.004, 0.913, 0.004]
        y_true_smooth = y_true_onehot * (1.0 - self.label_smoothing) + \
                        self.label_smoothing / tf.cast(num_classes, tf.float32)
        
        # Softmax → probabilities (float32 đảm bảo precision)
        probs = tf.nn.softmax(y_pred, axis=-1)
        probs = tf.clip_by_value(probs, 1e-7, 1.0)  # Tránh log(0)
        
        # Focal weight: (1 - p_correct)^gamma
        p_t = tf.reduce_sum(probs * y_true_onehot, axis=-1)
        focal_weight = tf.pow(1.0 - p_t, self.gamma)
        
        # Cross entropy với smoothed labels
        ce = -tf.reduce_sum(y_true_smooth * tf.math.log(probs), axis=-1)
        
        return tf.reduce_mean(focal_weight * ce)
    
    def get_config(self):
        config = super().get_config()
        config.update({"gamma": self.gamma, "label_smoothing": self.label_smoothing})
        return config

focal_loss = FocalLossFromLogits(gamma=2.0, label_smoothing=0.1)

# ============================================================
# [UPGRADE 4] WARMUP + COSINE DECAY LR SCHEDULE
# [FIX] Dùng ceiling cho steps_per_epoch + thêm get_config()
# ============================================================
steps_per_epoch = math.ceil(len(train_labels) / BATCH_SIZE)  # ceiling để không mất mẫu
total_steps = steps_per_epoch * EPOCHS
warmup_steps = steps_per_epoch * WARMUP_EPOCHS

class WarmupCosineDecay(tf.keras.optimizers.schedules.LearningRateSchedule):
    """LR: 0 → initial_lr (warmup tuyến tính) → 0 (cosine decay)"""
    def __init__(self, initial_lr, warmup_steps, total_steps):
        super().__init__()
        self.initial_lr = initial_lr
        self.warmup_steps = warmup_steps
        self.total_steps = total_steps
    
    def __call__(self, step):
        step = tf.cast(step, tf.float32)
        warmup = tf.cast(self.warmup_steps, tf.float32)
        total = tf.cast(self.total_steps, tf.float32)
        
        warmup_lr = self.initial_lr * (step / tf.maximum(warmup, 1.0))
        progress = (step - warmup) / tf.maximum(total - warmup, 1.0)
        progress = tf.minimum(progress, 1.0)  # clamp tránh vượt quá 1.0
        cosine_lr = self.initial_lr * 0.5 * (1.0 + tf.cos(np.pi * progress))
        
        return tf.where(step < warmup, warmup_lr, cosine_lr)
    
    def get_config(self):
        return {
            "initial_lr": self.initial_lr,
            "warmup_steps": self.warmup_steps,
            "total_steps": self.total_steps,
        }

lr_schedule = WarmupCosineDecay(INITIAL_LR, warmup_steps, total_steps)
optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)

model.compile(optimizer=optimizer, loss=focal_loss, metrics=["accuracy"])
print(f"\n🔬 Focal Loss (γ=2.0, smoothing=0.1) + Warmup Cosine Decay")
print(f"📈 LR: 0 →{INITIAL_LR} (warmup {WARMUP_EPOCHS}ep) → 0 (cosine {EPOCHS}ep)")

# ============================================================
# [UPGRADE 5] SMART EARLY STOPPING + MONITORING
# ============================================================
class SmartEarlyStopping(tf.keras.callbacks.Callback):
    def __init__(self, patience=8):
        super(SmartEarlyStopping, self).__init__()
        self.patience = patience
        self.best_acc = -1.0
        self.best_loss = float('inf')
        self.best_weights = None
        self.wait = 0

    def on_train_begin(self, logs=None):
        self.wait = 0

    def on_epoch_end(self, epoch, logs=None):
        val_loss = logs.get('val_loss')
        val_acc = logs.get('val_accuracy')
        
        try:
            current_lr = float(self.model.optimizer.learning_rate(self.model.optimizer.iterations))
        except:
            current_lr = 0.0
        
        is_improved = False
        if val_acc > self.best_acc:
            is_improved = True
        elif abs(val_acc - self.best_acc) < 1e-5 and val_loss < self.best_loss:
            is_improved = True
        if self.best_weights is None:
            is_improved = True

        if is_improved:
            self.best_acc = val_acc
            self.best_loss = val_loss
            self.best_weights = self.model.get_weights()
            self.wait = 0
            self.model.save_pretrained(MODEL_SAVE_PATH)
            print(f"\n🌟 [BEST] Epoch {epoch+1} → val_acc: {val_acc:.4f}, val_loss: {val_loss:.4f}, lr: {current_lr:.2e} 🌟")
            print(f"💾 Saved to {MODEL_SAVE_PATH}")
        else:
            self.wait += 1
            print(f"\n⏳ [{self.wait}/{self.patience}] No improve. Best: {self.best_acc:.4f} | lr: {current_lr:.2e}")
            if self.wait >= self.patience:
                self.model.stop_training = True
                print(f"\n🛑 Early Stop! Restoring best weights (acc={self.best_acc:.4f})")
                if self.best_weights is not None:
                    self.model.set_weights(self.best_weights)

early_stop = SmartEarlyStopping(patience=8)

print(f"\n{'='*80}")
print(f"🔥 BẮT ĐẦU TRAINING STAGE 30...")
print(f"   Steps/epoch: {steps_per_epoch} | Total steps: {total_steps} | Warmup: {warmup_steps}")
print(f"{'='*80}")
model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    class_weight=cw_dict,
    callbacks=[early_stop]
)

model.save_pretrained(MODEL_SAVE_PATH)
print(f"\n✅ FINAL Saved checkpoint to {MODEL_SAVE_PATH}")
print(f"🎯 Best val_accuracy: {early_stop.best_acc:.4f}")
