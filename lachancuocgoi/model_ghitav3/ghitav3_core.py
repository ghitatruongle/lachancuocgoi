# Phiên bản 2.1: BẢN SIÊU TỐI ƯU (Dành cho CPU 12 Luồng, RAM 16GB, GPU 6GB VRAM)
import os
os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2" # Giảm rác log của TF, tăng tốc load

import tensorflow as tf
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification
import pandas as pd
from sklearn.model_selection import train_test_split

# TỐI ƯU PHẦN CỨNG 1: Ép CPU chạy 10 Luồng (Để chừa 2 luồng cho Window/Trình duyệt)
tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

# TỐI ƯU PHẦN CỨNG 2: Ép VRAM chạy Full 6GB & Ngăn tràn RAM hệ thống
gpus = tf.config.experimental.list_physical_devices('GPU')
if gpus:
    try:
        # Ép ăn tối đa 6GB VRAM (6144 MB) để không làm treo máy
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=6144)])
        print("⚡ KÍCH HOẠT: Ép xung GPU VRAM lên mức cao nhất (Max 6GB)!")
    except RuntimeError as e:
        print(f"⚠️ GPU Cảnh báo: {e}")

# TỐI ƯU PHẦN CỨNG 3: Bật Mixed Precision (Tính toán trên card rời bằng float16)
try:
    policy = tf.keras.mixed_precision.Policy('mixed_float16')
    tf.keras.mixed_precision.set_global_policy(policy)
    print("⚡ BẬT MIXED PRECISION (FLOAT16): Tăng x2 Tốc độ Train!")
except Exception as e:
    print(f"⚠️ Cảnh báo GPU không hỗ trợ Mixed Precision: {e}")

BASE_MODEL = "google/mobilebert-uncased"
MAX_LENGTH = 256
BATCH_SIZE = 16 # Tăng từ 8 lên 16 vì có float16 và RAM GPU 6GB

try:
    if os.path.exists("vocab.txt"):
        TOKENIZER = MobileBertTokenizer(vocab_file="vocab.txt", local_files_only=True)
    else:
        TOKENIZER = MobileBertTokenizer.from_pretrained(BASE_MODEL)
except Exception as e:
    print("Cannot load tokenizer:", e)

def build_dataset_pipeline(texts, labels, batch_size=BATCH_SIZE):
    """
    TỐI ƯU PHẦN CỨNG 3: Áp dụng tf.data Pipeline
    Nạp dữ liệu từ RAM 16GB thẳng xuống GPU mà KHÔNG BỊ GIẬT LAG
    """
    # Bước 1: Mã hóa đồng loạt
    inputs = TOKENIZER(texts, padding="max_length", truncation=True, max_length=MAX_LENGTH, return_tensors="tf")
    dataset = tf.data.Dataset.from_tensor_slices((dict(inputs), labels))
    
    # Bước 2: Pipeline thần thánh (Cache RAM -> Shuffle nạp 1000 buffer -> Phân lô -> Nạp gối đầu bằng CPU 12 luồng)
    dataset = dataset.cache()
    dataset = dataset.shuffle(buffer_size=min(len(texts), 2000), seed=42)
    dataset = dataset.batch(batch_size)
    dataset = dataset.prefetch(tf.data.AUTOTUNE) # Ép CPU đào data trước 1 nhịp trong khi GPU đang xử lý
    
    return dataset

def run_training_stage(stage_num, data_file, epochs, learning_rate, prev_model_path, current_output_dir, num_labels, is_first_stage=False, is_final_stage=False):
    if not os.path.exists(data_file):
        print(f"❌ Không tìm thấy file dữ liệu: {data_file}")
        return
        
    df = pd.read_csv(data_file)
    print(f"✅ Đã nạp {len(df)} mẫu câu từ {data_file}")
    
    # Trộn Data ngẫu nhiên chống bias
    df = df.sample(frac=1, random_state=42).reset_index(drop=True)
    texts = df.iloc[:, 0].astype(str).tolist()
    labels = df.iloc[:, 1].astype(int).tolist()
    
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.2, random_state=42
    )
    
    print("⏳ Đang chuẩn bị tf.data Pipeline Cao Tốc...")
    train_dataset = build_dataset_pipeline(train_texts, train_labels)
    val_dataset = build_dataset_pipeline(val_texts, val_labels)
    
    print(f"🔄 Nạp mô hình từ: {prev_model_path}")
    if is_first_stage:
        model = TFMobileBertForSequenceClassification.from_pretrained(prev_model_path, num_labels=num_labels)
    else:
        model = TFMobileBertForSequenceClassification.from_pretrained(
            prev_model_path, num_labels=num_labels, ignore_mismatched_sizes=True
        )

    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])
    
    print(f"▶️ BẮT ĐẦU HUẤN LUYỆN SIÊU TỐC GIAI ĐOẠN {stage_num} (Epochs: {epochs}, LR: {learning_rate})")
    
    # Callback Tối Ưu Tự Động Lưu Trạng Thái Tốt Nhất
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=3, restore_best_weights=True)
    ]
    
    model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=epochs,
        callbacks=callbacks
    )
    
    print(f"💾 Lưu trọng số Giai đoạn {stage_num} (Bản Tốt Nhất) vào: {current_output_dir}")
    model.save_pretrained(current_output_dir)
    
    if is_final_stage:
        print(f"🚀 Giai đoạn cuối: Xuất TFLite model siêu nhẹ...")
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS, tf.lite.OpsSet.SELECT_TF_OPS]
        
        tflite_model = converter.convert()
        with open("ghitav3.tflite", "wb") as f:
            f.write(tflite_model)
        print("✅ Đã lưu ghitav3.tflite (Chạy siêu tốc trên Mobile)")
        
        with open("vocab.txt", "w", encoding="utf-8") as f:
            for token in TOKENIZER.vocab.keys():
                f.write(token + '\n')
        print("✅ Đã lưu Cấu trúc Từ vựng vocab.txt")

