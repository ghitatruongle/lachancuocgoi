import os
import glob
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification
import time
import shutil

# Khởi tạo môi trường
os.environ["PYTHONIOENCODING"] = "utf-8"
os.environ["TF_USE_LEGACY_KERAS"] = "1"

# Tối ưu RAM & CPU
tf.config.threading.set_intra_op_parallelism_threads(8)
tf.config.threading.set_inter_op_parallelism_threads(2)

BASE_MODEL = "google/mobilebert-uncased"
MAX_LENGTH = 256
try:
    TOKENIZER = MobileBertTokenizer.from_pretrained(BASE_MODEL)
except:
    # Fallback cho trường hợp load offline
    print("Dùng Tokenizer nội bộ...")
    from transformers import AutoTokenizer
    TOKENIZER = MobileBertTokenizer(vocab_file="vocab.txt")

def encode_data(texts, labels):
    inputs = TOKENIZER(texts, padding=True, truncation=True, max_length=MAX_LENGTH, return_tensors="tf")
    return dict(inputs), tf.convert_to_tensor(labels)

def main():
    print("====================================================================")
    print("🌟 BẮT ĐẦU GIAI ĐOẠN 18: ULTIMATE MASTER MIX (DYNAMIC LEARNING) 🌟")
    print("====================================================================")
    
    # 1. Thu thập data từ Stage 9 đến Stage 17 (Theo yêu cầu mở rộng)
    csv_files = []
    for i in range(9, 18):
        files = glob.glob(f"stage{i}_*.csv")
        csv_files.extend(files)
        
    if not csv_files:
        print("❌ Không tìm thấy các file dữ liệu từ Giai đoạn 9-17!")
        return
        
    print(f"✅ Tìm thấy {len(csv_files)} tệp dữ liệu:")
    for f in csv_files:
        print(f"  - {f}")
        
    dfs = []
    for f in csv_files:
        try:
            df = pd.read_csv(f)
            # Lọc lấy đúng cột text và label
            if len(df.columns) >= 2:
                # Ép kiểu header cho mọi file
                df.columns = ['text', 'label'] + list(df.columns[2:])
                dfs.append(df[['text', 'label']])
        except:
            pass
            
    master_df = pd.concat(dfs, ignore_index=True).dropna()
    print(f"\n🔥 GỘP THÀNH CÔNG BỂ CHỨA MASTER: {len(master_df)} câu lừa đảo/an toàn các loại!")
    
    # 2. Nạp Model đã tốt nghiệp từ vòng 17
    prev_model_path = "checkpoint_stage17_Final"
    if not os.path.exists(prev_model_path):
        print(f"❌ Bạn chưa có {prev_model_path}. Vui lòng chờ lệnh Stage 17 chạy xong 100% rồi mới bắt đầu lệnh này!")
        return
        
    print(f"🔄 Nạp bộ não thượng thừa từ: {prev_model_path}")
    model = TFMobileBertForSequenceClassification.from_pretrained(
        prev_model_path, num_labels=23, ignore_mismatched_sizes=True
    )
    
    # Biên dịch model
    learning_rate = 1e-5
    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])
    
    # 3. Chạy thuật toán Customized Random Batched Learning
    TOTAL_EPOCHS = 10  # Vì mỗi vòng đã kéo tận vài ngàn data nên 10 vòng là cực kỳ chất lượng
    print(f"\n🚀 SIÊU CẤP ĐÁNH LỪA AI: Bắt đầu {TOTAL_EPOCHS} vòng huấn luyện xáo bài...")
    
    for epoch in range(1, TOTAL_EPOCHS + 1):
        print(f"\n==================== 🌀 LẶP (EPOCH) {epoch}/{TOTAL_EPOCHS} ====================")
        
        # CƠ CHẾ SÁT THỦ: Lấy ngẫu nhiên 70% dữ liệu để nặn hình cho Epoch này, vứt 30% đi để xóa ký ức
        sampled_df = master_df.sample(frac=0.7, random_state=None)
        print(f"🎲 Đã bốc {len(sampled_df)} bản ghi ({len(sampled_df)*100//len(master_df)}%) ngẫu nhiên để huấn luyện...")
        
        texts = sampled_df['text'].astype(str).tolist()
        labels = sampled_df['label'].astype(int).tolist()
        
        # Cắt Validation
        train_texts, val_texts, train_labels, val_labels = train_test_split(
            texts, labels, test_size=0.15, random_state=42 # cố định Validation set nhỏ
        )
        
        print(f"Đang biên dịch Tensor cho văn bản (chiều dài tối đa có thể lên {MAX_LENGTH} - Gây nóng CPU)")
        train_inputs, train_labels_tf = encode_data(train_texts, train_labels)
        val_inputs, val_labels_tf = encode_data(val_texts, val_labels)
        
        print("🤖 Bắt đầu nuốt dữ liệu...")
        model.fit(
            train_inputs, train_labels_tf,
            validation_data=(val_inputs, val_labels_tf),
            epochs=1,    # Chạy model.fit đúng 1 lần cho gói Data đã random này
            batch_size=8 # Máy bạn khỏe có thể đẩy lên 16 nhưng 8 là tốt nhất để nó nuốt từ từ
        )
        
    # 4. Save the Ultimate Checkpoint and TFLite
    print("\n-----------------------------------------------------------")
    current_output_dir = "checkpoint_stage18_Ultimate"
    print(f"💾 Lưu bộ não Thần Ký (Checkpoint) vào: {current_output_dir}")
    model.save_pretrained(current_output_dir)
    
    print("\n💎💎💎 HOÀN THÀNH GIAI ĐOẠN 18! 💎💎💎")
    print(f"Mô hình gốc (Weights) đã được lưu sẵn sàng để bước vào Trận cuối cùng (Giai đoạn 19).")

if __name__ == "__main__":
    main()
