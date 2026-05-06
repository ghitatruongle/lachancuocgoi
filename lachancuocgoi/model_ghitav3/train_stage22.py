import os
import pandas as pd
import tensorflow as tf
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

# 1. TỐI ƯU TÀI NGUYÊN BẮT BUỘC (Vẫn y hệt bản cũ)
tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=6144)])
        print("🎮 Đã kích hoạt: Giới hạn VRAM GPU ở mức 6GB")
    except RuntimeError as e:
        print(e)
        
try:
    policy = tf.keras.mixed_precision.Policy('mixed_float16')
    tf.keras.mixed_precision.set_global_policy(policy)
    print("⚡ Bật Mixed Precision Float16: Tăng gấp x2 Tốc độ")
except Exception:
    pass

print("="*80)
print("🛡️ BẮT ĐẦU HUẤN LUYỆN GIAI ĐOẠN 22: ĐẶC TRỊ CHỐNG BÁO ĐỘNG GIẢ (HARD NEGATIVES) 🛡️")
print("="*80)

DATA_PATH = "stage22_scenarios_hard_negatives_cleaned.csv"
MODEL_LOAD_PATH = "checkpoint_stage21_Final"
MODEL_SAVE_PATH = "checkpoint_stage22_Final"
VOCAB_PATH = "vocab.txt"

# 2. THAM SỐ HUẤN LUYỆN ĐẶC BIỆT CỦA GIAI ĐOẠN 22
MAX_LEN = 256
BATCH_SIZE = 16
EPOCHS = 15          # GIAI ĐOẠN NHẠY CẢM: KHÔNG VƯỢT QUÁ 15 VÒNG
LEARNING_RATE = 1e-5 # Tốc độ nhỏ giọt cố định, không dùng siêu tốc ban đầu nữa
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Lỗi: Không thấy tập {DATA_PATH}")
    exit(1)
if not os.path.exists(MODEL_LOAD_PATH):
    print(f"❌ Lỗi: Không thấy trọng số ở {MODEL_LOAD_PATH}")
    exit(1)

# 3. NẠP DỮ LIỆU & CACHE TRÊN RAM 
print("⏳ Đang chuẩn bị tf.data Pipeline Cao Tốc...")
df = pd.read_csv(DATA_PATH)
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()

train_size = int(0.8 * len(texts))
train_texts, val_texts = texts[:train_size], texts[train_size:]
train_labels, val_labels = labels[:train_size], labels[train_size:]

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)

train_inputs = tokenizer(train_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
train_dataset = tf.data.Dataset.from_tensor_slices((dict(train_inputs), train_labels))
train_dataset = train_dataset.shuffle(buffer_size=min(len(train_texts), 2000), seed=99).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

val_inputs = tokenizer(val_texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
val_dataset = tf.data.Dataset.from_tensor_slices((dict(val_inputs), val_labels))
val_dataset = val_dataset.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

# 4. LOAD MODEL TỪ STAGE 21
print(f"🧠 Đang kế thừa bộ não từ Giai đoạn 21: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

optimizer = tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])

# 5. GIÁM SÁT RỦI RO NGHIÊM NGẶT (SIÊU CẤP ĐỘ)
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_accuracy', 
    patience=3, # Ngắt cầu chì chỉ sau 3 vòng không chạm mức mới (Tránh tẩy não)
    restore_best_weights=True,
    verbose=1
)

# 6. HUẤN LUYỆN
print("\n🔥 VÀO LÒ LUYỆN: Bắt đầu trung hòa nhị phân (Patience=3)...")
model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    callbacks=[early_stop]
)

# 7. Lưu model bằng HuggingFace save_pretrained (CHUẨN, không lỗi directory)
print(f"\n💾 Đang lưu trọng số vào {MODEL_SAVE_PATH}...")
model.save_pretrained(MODEL_SAVE_PATH)
print("="*80)
print(f"🎉 HOÀN TẤT GIAI ĐOẠN 22. TRỌNG SỐ LƯU TẠI: {MODEL_SAVE_PATH}")
print("Mô hình chính thức phân biệt được Giao tiếp an toàn và Lừa đảo qua Mạch câu!")
print("="*80)
