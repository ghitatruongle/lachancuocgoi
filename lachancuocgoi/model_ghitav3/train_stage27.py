import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
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

# [GPU CONFIG] Chế độ Memory Growth để tránh OOM trên Windows
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
print("🧠 STAGE 27: PSYCHOLOGICAL MANIPULATION 🧠")
print("TARGET: LEARN FAKE AUTHORITIES & SEXTORTION (LABEL 0, 9)")
print("="*80)

DATA_PATH = "stage27_scenarios_psych_manipulation.csv"
REPLAY_PATH = "stage23_master_replay.csv"
MODEL_LOAD_PATH = "checkpoint_stage26_Final"
MODEL_SAVE_PATH = "checkpoint_stage27_Final"
VOCAB_PATH = "vocab.txt"

MAX_LEN = 50
BATCH_SIZE = 16
EPOCHS = 50
LEARNING_RATE = 1e-5
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Không tìm thấy {DATA_PATH}")
    exit(1)

# Logic trộn Replay Buffer (60/40) để chống Quên thảm họa
df_new = pd.read_csv(DATA_PATH).dropna(subset=['text', 'label'])
df_old = pd.DataFrame()
if os.path.exists(REPLAY_PATH):
    df_old_raw = pd.read_csv(REPLAY_PATH).dropna(subset=['text', 'label'])
    num_old_samples = int(len(df_new) * 0.66) 
    num_old_samples = min(num_old_samples, len(df_old_raw))
    df_old = df_old_raw.sample(n=num_old_samples, random_state=42)
    print(f"🔄 Replay Buffer: Kéo {len(df_old)} mẫu cũ vào trộn cùng {len(df_new)} mẫu mới.")
else:
    print(f"⚠️ Không tìm thấy tệp {REPLAY_PATH}, chạy không có bộ đệm!")

df = pd.concat([df_new, df_old], ignore_index=True)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()

train_texts, val_texts, train_labels, val_labels = train_test_split(
    texts, labels, test_size=0.2, random_state=42, stratify=labels
)

# Tính toán Class Weights tự động
unique_labels = np.unique(train_labels)
cw_values = class_weight.compute_class_weight('balanced', classes=unique_labels, y=train_labels)
cw_dict = {int(label): weight for label, weight in zip(unique_labels, cw_values)}

for i in range(NUM_LABELS):
    if i not in cw_dict:
        cw_dict[i] = 1.0

if 0 in cw_dict: cw_dict[0] = cw_dict[0] * 2.5
if 9 in cw_dict: cw_dict[9] = cw_dict[9] * 2.5

print(f"📊 Training distribution: {dict(zip(*np.unique(train_labels, return_counts=True)))}")

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
train_encodings = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_encodings = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")

# [OOM FIX] Giảm Shuffle Buffer xuống 300 để cực kỳ an toàn
train_dataset = tf.data.Dataset.from_tensor_slices((dict(train_encodings), train_labels)).shuffle(300).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)
val_dataset = tf.data.Dataset.from_tensor_slices((dict(val_encodings), val_labels)).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

print(f"🧠 Loading brain from: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# [TRIET DE FIX OOM] Selective Fine-tuning cho 6GB VRAM
model.mobilebert.trainable = False # Đầu tiên Freeze toàn bộ backbone
for layer in model.mobilebert.encoder.layer[-6:]: # Chỉ mở khóa 6 tầng Transformer cuối
    layer.trainable = True
model.classifier.trainable = True # Đảm bảo đầu ra phân loại luôn mở
print("🔓 Selective Fine-tuning: Last 6 Layers & Classifier UNFROZEN")

optimizer = tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])

reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor='val_loss', factor=0.5, patience=3, min_lr=1e-7, verbose=1
)

# [Smart Early Stopping] - Phiên bản Touch & Save (Lưu đỉnh cao)
class SmartEarlyStopping(tf.keras.callbacks.Callback):
    def __init__(self, patience=5):
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
        
        is_improved = False
        if val_acc > self.best_acc:
            is_improved = True
        elif abs(val_acc - self.best_acc) < 1e-5 and val_loss < self.best_loss:
            is_improved = True
            
        if self.best_weights is None: is_improved = True

        if is_improved:
            self.best_acc = val_acc
            self.best_loss = val_loss
            self.best_weights = self.model.get_weights()
            self.wait = 0
            self.model.save_pretrained(MODEL_SAVE_PATH)
            print(f"\n🌟 [Smart Save] Cột mốc mới (Epoch {epoch+1}) -> val_acc: {val_acc:.4f}, val_loss: {val_loss:.4f} 🌟")
            print(f"💾 Checkpoint đã được cập nhật tại {MODEL_SAVE_PATH}")
        else:
            self.wait += 1
            print(f"\n⚠️ [Smart Mon] Chưa cải thiện ({self.wait}/{self.patience}). Best: acc: {self.best_acc:.4f}, loss: {self.best_loss:.4f}")
            if self.wait >= self.patience:
                self.model.stop_training = True
                print(f"\n🛑 [Early Stop] Dừng sớm. Đang khôi phục trọng số tốt nhất...")
                if self.best_weights is not None:
                    self.model.set_weights(self.best_weights)

early_stop = SmartEarlyStopping(patience=5)

print(f"\n🔥 Bắt đầu huấn luyện...")
model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    class_weight=cw_dict,
    callbacks=[reduce_lr, early_stop]
)

model.save_pretrained(MODEL_SAVE_PATH)
print(f"✅ FINAL Saved checkpoint to {MODEL_SAVE_PATH}")
