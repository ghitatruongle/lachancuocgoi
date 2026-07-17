import os
# Ép buộc TensorFlow dùng Keras 2 để tương thích với Transformers
os.environ["TF_USE_LEGACY_KERAS"] = "1"

import tensorflow as tf
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification
import pandas as pd
from sklearn.model_selection import train_test_split

# --- 1. CẤU HÌNH THAM SỐ (Hyperparameters) ---
base_model_name = "google/mobilebert-uncased"
custom_name = "ghitav2"  # Tên mô hình sau 3 giai đoạn kết thúc
num_labels_final = 23    # 22 nhãn lừa đảo + 1 nhãn an toàn
max_length = 256

# Tên các file dữ liệu mà bạn cần chuẩn bị cho 3 tiến trình
file_stage1 = "train_phothong.csv"
file_stage2 = "train_vungmien.csv"
file_stage3 = "train_intents.csv" # File dữ liệu cuối cùng ngắm thẳng lừa đảo

print(f"--- BẮT ĐẦU HUẤN LUYỆN LIÊN TỤC 3 GIAI ĐOẠN CHO {custom_name.upper()} ---")

# --- 2. KHỞI TẠO TOKENIZER ---
tokenizer = MobileBertTokenizer.from_pretrained(base_model_name)

def encode_data(texts, labels):
    """Hàm hỗ trợ token hóa văn bản thành mảng vector TensorFlow"""
    inputs = tokenizer(texts, padding=True, truncation=True, max_length=max_length, return_tensors="tf")
    return dict(inputs), tf.convert_to_tensor(labels)

def train_stage(model_path, num_labels, data_path, epochs, learning_rate, output_dir, is_first_stage=False):
    """Hàm lõi huấn luyện từng giai đoạn"""
    if not os.path.exists(data_path):
        print(f"⚠️ CẢNH BÁO: Không tìm thấy file dữ liệu '{data_path}'. Bỏ qua giai đoạn này!")
        return None
        
    df = pd.read_csv(data_path)
    print(f"✅ Đã nạp {len(df)} mẫu câu từ {data_path}")
    
    # Chia 80% Train, 20% Validation để theo dõi học vẹt (overfitting)
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        df["text"].tolist(), df["label"].tolist(), test_size=0.2, random_state=42
    )
    
    train_inputs, train_labels_tf = encode_data(train_texts, train_labels)
    val_inputs, val_labels_tf = encode_data(val_texts, val_labels)
    
    print(f"Nạp mô hình từ: {model_path} (Số nhãn lớp cuối: {num_labels})")
    
    # Nếu là mô hình tiếp nối (không phải HuggingFace gốc), cần bật ignore_mismatched_sizes
    # Vì số nhãn của Giai đoạn 2 khác Giai đoạn 1 và khác Giai đoạn 3
    if is_first_stage:
        model = TFMobileBertForSequenceClassification.from_pretrained(model_path, num_labels=num_labels)
    else:
        model = TFMobileBertForSequenceClassification.from_pretrained(
            model_path, num_labels=num_labels, ignore_mismatched_sizes=True
        )

    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])
    
    print(f"--- Đang phân tích và học tập (Lặp: {epochs} lần, Tốc độ học: {learning_rate}) ---")
    model.fit(
        train_inputs, train_labels_tf,
        validation_data=(val_inputs, val_labels_tf),
        epochs=epochs,
        batch_size=8
    )
    
    print(f"Lưu trọng số nháp của Giai đoạn này vào thư mục: {output_dir}")
    model.save_pretrained(output_dir)
    return model

# =========================================================================
# GIAI ĐOẠN 1: TIẾNG VIỆT PHỔ THÔNG (100 Epochs)
# =========================================================================
print("\n" + "="*60)
print(f"GIAI ĐOẠN 1: DẠY TIẾNG VIỆT CHUẨN (100 LẦN)")
print("="*60)

# Khai báo model_path luôn mang tên model gốc lúc mới khởi tạo
model_path_current = base_model_name

# Lấy số nhãn tự động từ file CSV 1 (nếu file tồn tại)
if os.path.exists(file_stage1):
    df_s1 = pd.read_csv(file_stage1)
    num_labels_s1 = df_s1["label"].nunique()
    
    model_s1_result = train_stage(
        model_path=model_path_current, 
        num_labels=num_labels_s1, 
        data_path=file_stage1, 
        epochs=100, 
        learning_rate=2e-5, 
        output_dir="./ghitav2_stage1",
        is_first_stage=True
    )
    if model_s1_result is not None:
        model_path_current = "./ghitav2_stage1"  # Cập nhật đường dẫn tiến hóa cho GĐ2 học tiếp
else:
    print(f"-> Ghi chú: Vui lòng tạo tệp '{file_stage1}' (gồm cột text và label) ở ổ đĩa để hệ thống chạy Tiến trình 1.")


# =========================================================================
# GIAI ĐOẠN 2: TIẾNG VIỆT VÙNG MIỀN & KHẨU NGỮ (50 Epochs)
# =========================================================================
print("\n" + "="*60)
print(f"GIAI ĐOẠN 2: LÀM QUEN TIẾNG LÓNG & PHƯƠNG NGỮ (50 LẦN)")
print("="*60)

if os.path.exists(file_stage2):
    df_s2 = pd.read_csv(file_stage2)
    num_labels_s2 = df_s2["label"].nunique()
    
    # Học tiếp nối từ model_path_current của Giai đoạn 1 
    # (Nếu GĐ1 bị bỏ qua vì thiếu file, nó sẽ tự động trỏ về google/mobilebert-uncased để làm base)
    model_s2_result = train_stage(
        model_path=model_path_current, 
        num_labels=num_labels_s2, 
        data_path=file_stage2, 
        epochs=50, 
        learning_rate=1e-5,  # Chú ý: LR giảm 1 nửa so với cũ để tránh quên phần trước
        output_dir="./ghitav2_stage2",
        is_first_stage=(model_path_current == base_model_name) 
    )
    if model_s2_result is not None:
        model_path_current = "./ghitav2_stage2"
else:
    print(f"-> Ghi chú: Vui lòng tạo tệp '{file_stage2}' để hệ thống chạy Tiến trình 2.")


# =========================================================================
# GIAI ĐOẠN 3: PHÂN LOẠI 23 KỊCH BẢN LỪA ĐẢO QUA train_intents.csv (10 Epochs)
# =========================================================================
print("\n" + "="*60)
print(f"GIAI ĐOẠN 3: TINH CHỈNH PHÂN LOẠI LỪA ĐẢO QUA train_intents (10 LẦN)")
print("="*60)

if os.path.exists(file_stage3):
    model_final = train_stage(
        model_path=model_path_current, 
        num_labels=num_labels_final,  # Chắc chắn là số 23
        data_path=file_stage3, 
        epochs=10, 
        learning_rate=2e-5, 
        output_dir=custom_name,
        is_first_stage=(model_path_current == base_model_name)
    )

    if model_final is not None:
        # =========================================================================
        # BƯỚC CUỐI CÙNG: LƯỢNG TỬ HÓA & ĐÓNG GÓI RA FILE TFLITE CHO ANDROID
        # =========================================================================
        print(f"\n--- Đang lượng tử hóa (Float16) sang file {custom_name}.tflite cho Android ---")
        converter = tf.lite.TFLiteConverter.from_keras_model(model_final)
        
        # Bật tối ưu hóa kích thước model và tương thích Android
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS, tf.lite.OpsSet.SELECT_TF_OPS]
        
        tflite_model = converter.convert()

        with open(f"{custom_name}.tflite", "wb") as f:
            f.write(tflite_model)

        print(f"✅ HOÀN TẤT TUYỆT ĐỐI! File '{custom_name}.tflite' nhỏ gọn đã nằm trong thư mục.")
        
        # XUẤT LUÔN TỪ ĐIỂN ĐI KÈM
        with open("vocab.txt", "w", encoding="utf-8") as f:
            for token in tokenizer.vocab.keys():
                f.write(token + '\n')
        print(f"✅ File 'vocab.txt' đã được khởi tạo/cập nhật!")
else:
    print(f"❌ Không tìm thấy tệp '{file_stage3}'. Dừng chương trình.")
