import os
import pandas as pd
import tensorflow as tf
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification

# Khắc phục lỗi tương thích Keras/Tensorflow
os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2" # Giảm lag terminal

# TỐI ƯU 1: Chừa 2 luồng CPU cho anh xài (Dùng đúng 10 luồng)
tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

# TỐI ƯU 2: Nhốt GPU lại không cho ăn lố 6GB
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=6144)])
        print("🎮 Bọc lót GPU VRAM: Tối đa 6GB (Đã bật mức tản nhiệt an toàn)")
    except RuntimeError as e:
        print(e)

# TỐI ƯU 3: Cắn thuốc trợ lực Mixed Precision (Tính toán trên card rời bằng float16)
try:
    policy = tf.keras.mixed_precision.Policy('mixed_float16')
    tf.keras.mixed_precision.set_global_policy(policy)
    print("⚡ Bật Mixed Precision Float16: Model load siêu nhẹ và train siêu cấp!")
except Exception as e:
    pass

print("="*80)
print("🚀 BẮT ĐẦU HUẤN LUYỆN GIAI ĐOẠN 21: GEN-Z SLANG & TEENCODE DECODER 🚀")
print("="*80)

# Cấu hình đường dẫn
DATA_PATH = "stage21_scenarios_genz_slang.csv"
MODEL_LOAD_PATH = "checkpoint_stage20_Final"
MODEL_SAVE_PATH = "checkpoint_stage21_Final"
VOCAB_PATH = "vocab.txt"

# Tham số huấn luyện TỐI ƯU NHẤT
MAX_LEN = 256
BATCH_SIZE = 16   # Tăng luồng nạp dữ liệu để học nhanh hơn
EPOCHS = 30       # Giới hạn an toàn, tránh bị overfit
NUM_LABELS = 23

if not os.path.exists(DATA_PATH):
    print(f"❌ Lỗi: Không thấy tập dữ liệu {DATA_PATH}. Chạy file sinh data trước!")
    exit(1)
if not os.path.exists(MODEL_LOAD_PATH):
    print(f"❌ Lỗi: Không thấy trọng số gốc {MODEL_LOAD_PATH}.")
    exit(1)

# 1. Đọc dữ liệu & Tokenizer
print("⏳ Khởi tạo Tokenizer và nạp Dữ liệu...")
df = pd.read_csv(DATA_PATH)

# Trộn dữ liệu ngẫu nhiên cục bộ thêm một lần bằng Pandas
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

texts = df['text'].astype(str).tolist()
labels = df['label'].astype(int).tolist()

tokenizer = MobileBertTokenizer(vocab_file=VOCAB_PATH, local_files_only=True)
inputs = tokenizer(texts, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
dataset = tf.data.Dataset.from_tensor_slices((dict(inputs), labels))

# Phân tách tập huấn luyện/thẩm định (80/20)
dataset_size = len(texts)
train_size = int(0.8 * dataset_size)

dataset = dataset.shuffle(buffer_size=dataset_size, seed=99)
train_dataset = dataset.take(train_size).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)
val_dataset = dataset.skip(train_size).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

# 2. Load Model Giai đoạn 20 (Bộ não kế thừa)
print(f"🧠 Đang nạp hệ trọng số cũ từ: {MODEL_LOAD_PATH}...")
model = TFAutoModelForSequenceClassification.from_pretrained(MODEL_LOAD_PATH, num_labels=NUM_LABELS)

# 3. Kỹ thuật Tối ưu Hóa (OPTIMIZATION TRICKS)
# Sử dụng Cosine Decay: Cho phép AI học với tốc độ cực nhanh lúc đầu, và "mài giũa" chậm dần ở khúc cuối
steps_per_epoch = train_size // BATCH_SIZE
total_steps = steps_per_epoch * EPOCHS

lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
    initial_learning_rate=2.5e-5, # Khởi đầu mạnh mẽ kích thích dây thần kinh
    decay_steps=total_steps,
    alpha=0.04  # Lời thoái cực thấp chạm ngưỡng 1e-6 để mượt mà vào form
)

optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)
loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
model.compile(optimizer=optimizer, loss=loss, metrics=['accuracy'])

# 4. Trợ lý Giám sát (Callback)
# Tự dừng nếu AI chững lại, giữ lại bộ trọng số tốt nhất trong RAM
early_stop = tf.keras.callbacks.EarlyStopping(
    monitor='val_accuracy', 
    patience=5,  # Chờ tối đa 5 vòng lặp, nếu không khôn hơn thì tắt máy
    restore_best_weights=True,
    verbose=1
)

# 5. Khởi chạy Rèn Sắt (Deep Fine-Tuning)
print("\n🔥 VÀO LÒ LUYỆN: Deep Fine-Tuning Mode Khởi Động...")
history = model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    callbacks=[early_stop]
)

# 6. Lưu model bằng HuggingFace save_pretrained (CHUẨN NHẤT, không bị lỗi directory)
print(f"\n💾 Đang lưu trọng số vào {MODEL_SAVE_PATH}...")
model.save_pretrained(MODEL_SAVE_PATH)
print("="*80)
print(f"🎉 HOÀN TẤT GIAI ĐOẠN 21. TRỌNG SỐ ĐÃ ĐƯỢC CHỐT TẠI: {MODEL_SAVE_PATH}")
print("Mô hình chính thức giải nén được bộ ngôn ngữ Gen-Z cực đoan!")
print("="*80)
