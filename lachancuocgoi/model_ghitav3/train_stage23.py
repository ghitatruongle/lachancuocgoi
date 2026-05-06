import os
import pandas as pd
import tensorflow as tf
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

# 1. CẤU HÌNH PHẦN CỨNG (Tối ưu cho CPU 12 luồng, RAM 16GB, GPU 6GB)
tf.config.threading.set_intra_op_parallelism_threads(10) # Chửa 2 luồng cho Window
tf.config.threading.set_inter_op_parallelism_threads(10)

gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        # Ép ăn tối đa 6GB VRAM (6144 MB)
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=6144)])
        print("🎮 GPU VRAM Cap: Lock at 6GB (Safety Mode)")
    except RuntimeError as e:
        print(e)
        
try:
    policy = tf.keras.mixed_precision.Policy('mixed_float16')
    tf.keras.mixed_precision.set_global_policy(policy)
    print("⚡ Mixed Precision: ENABLED (Speed x2)")
except Exception:
    pass

print("="*80)
print("🏆 BẮT ĐẦU GIAI ĐOẠN 23: TRẬN CHUNG KẾT (MASTER MULTITASK REPLAY) 🏆")
print("="*80)

# 2. ĐƯỜNG DẪN & THAM SỐ
DATA_PATH = "stage23_master_replay.csv"
MODEL_LOAD_PATH = "checkpoint_stage22_Final"
MODEL_SAVE_PATH = "checkpoint_stage23_Final" # Bản Gold cuối cùng
VOCAB_PATH = "vocab.txt"

MAX_LEN = 256
BATCH_SIZE = 16
EPOCHS = 300 # Huấn luyện sâu để hội tụ toàn bộ kiến thức
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Lỗi: Không thấy tập {DATA_PATH}. Hãy chạy generate_stage23_data.py trước!")
    exit(1)
if not os.path.exists(MODEL_LOAD_PATH):
    print(f"❌ Lỗi: Không thấy trọng số ở {MODEL_LOAD_PATH}")
    exit(1)

# 3. PIPELINE DỮ LIỆU CAO TỐC
print("⏳ Đang nhào nặn siêu dữ liệu Master...")
df = pd.read_csv(DATA_PATH)

# Cứu hộ tự động: Dọn dẹp các dòng rỗng (NaN) và dạt rác (nếu file CSV bị thừa cột)
df['label'] = pd.to_numeric(df['label'], errors='coerce')
df = df.dropna(subset=['text', 'label'])
df = df[df['text'].astype(str).str.strip() != '']

df = df.sample(frac=1, random_state=77).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()

train_size = int(0.85 * len(texts)) # Giữ 15% để validate cực khắt khe
train_texts, val_texts = texts[:train_size], texts[train_size:]
train_labels, val_labels = labels[:train_size], labels[train_size:]

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)

train_inputs = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
train_dataset = tf.data.Dataset.from_tensor_slices((dict(train_inputs), train_labels))
train_dataset = train_dataset.shuffle(buffer_size=min(len(train_texts), 3000), seed=42).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

val_inputs = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_dataset = tf.data.Dataset.from_tensor_slices((dict(val_inputs), val_labels))
val_dataset = val_dataset.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

# 4. LOAD MODEL TỪ STAGE 22
print(f"🧠 Nạp bộ não tiền bối từ: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# 5. COSINE DECAY: CHIẾN THUẬT RÈN SẮT
steps_per_epoch = train_size // BATCH_SIZE
total_steps = steps_per_epoch * EPOCHS

lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
    initial_learning_rate=2e-5,
    decay_steps=total_steps,
    alpha=0.05 # Điểm dừng 1e-6
)

optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])

# 6. GIÁM SÁT CHIẾN TRƯỜNG
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_accuracy', 
    patience=10, # Chờ 10 vòng để AI tổng hợp tri thức khổng lồ
    restore_best_weights=True,
    verbose=1
)

# 7. KHỞI CHẠY (THE FINAL RUN)
print("\n🔥 LÒ LUYỆN CUỐI CÙNG: Đang đúc siêu phẩm GhitaV3 Ver 5...")
model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    callbacks=[early_stop]
)

# 7.5 Lưu checkpoint bằng HuggingFace save_pretrained (CHUẨN, không lỗi directory)
print(f"\n💾 Đang lưu trọng số vào {MODEL_SAVE_PATH}...")
model.save_pretrained(MODEL_SAVE_PATH)

# 8. XUẤT BẢN TFLITE (Mục tiêu cuối cùng)
print("\n🚀 GIAI ĐOẠN CUỐI: Xuất xưởng ghitav3.tflite vào thư mục ver5(21-23)...")
output_dir = "ver5(21-23)"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS, tf.lite.OpsSet.SELECT_TF_OPS]

tflite_model = converter.convert()
output_path = os.path.join(output_dir, "ghitav3.tflite")
with open(output_path, "wb") as f:
    f.write(tflite_model)

print("="*80)
print("✅ HOÀN TẤT CHIẾN DỊCH GHITAV3!")
print(f"💎 Model: {output_path}")
print(f"🧠 Checkpoint: {MODEL_SAVE_PATH}")
print("Mô hình đã sẵn sàng thực chiến với độ chính xác nhãn tuyệt đối cao nhất!")
print("="*80)
