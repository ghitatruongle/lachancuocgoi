import os
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification

# Môi trường
os.environ["PYTHONIOENCODING"] = "utf-8"
os.environ["TF_USE_LEGACY_KERAS"] = "1"

# Tối ưu lõi CPU
tf.config.threading.set_intra_op_parallelism_threads(8)
tf.config.threading.set_inter_op_parallelism_threads(2)

BASE_MODEL = "google/mobilebert-uncased"
MAX_LENGTH = 256
try:
    TOKENIZER = MobileBertTokenizer.from_pretrained(BASE_MODEL)
except:
    TOKENIZER = MobileBertTokenizer(vocab_file="vocab.txt")

def encode_data(texts, labels):
    inputs = TOKENIZER(texts, padding=True, truncation=True, max_length=MAX_LENGTH, return_tensors="tf")
    return dict(inputs), tf.convert_to_tensor(labels)

# 🚦 CẢM BIẾN TỰ ĐỘNG NGẮT HUẤN LUYỆN DO USER ĐỀ XUẤT
class ThangDoVotNguong(tf.keras.callbacks.Callback):
    def on_epoch_end(self, epoch, logs=None):
        val_acc = logs.get('val_accuracy')
        if val_acc is not None and val_acc >= 0.45:
            print(f"\n=======================================================")
            print(f"✅ ĐẠT NGƯỠNG AN TOÀN: Val_Accuracy = {val_acc:.4f} >= 45%")
            print(f"🛑 Dừng huấn luyện sớm tại Vòng {epoch + 1} để chống Học vẹt!")
            print(f"=======================================================")
            self.model.stop_training = True

def main():
    print("====================================================================")
    print("🧠 BẮT ĐẦU GIAI ĐOẠN 19: TRÍ NHỚ HỘI THOẠI (BỨT TỐC)")
    print("====================================================================")
    
    data_file = "stage19_scenarios_sliding_window.csv"
    if not os.path.exists(data_file):
        print(f"❌ Không tìm thấy {data_file}")
        return
        
    df = pd.read_csv(data_file)
    texts = df['text'].astype(str).tolist()
    labels = df['label'].astype(int).tolist()
    
    train_texts, val_texts, train_labels, val_labels = train_test_split(
        texts, labels, test_size=0.15, random_state=42
    )
    
    print("Đang nén dữ liệu qua MobileBert Tokenizer...")
    train_inputs, train_labels_tf = encode_data(train_texts, train_labels)
    val_inputs, val_labels_tf = encode_data(val_texts, val_labels)

    prev_model_path = "checkpoint_stage18_Ultimate"
    print(f"🔄 Nạp trí nhớ thượng thừa từ: {prev_model_path}")
    model = TFMobileBertForSequenceClassification.from_pretrained(
        prev_model_path, num_labels=23, ignore_mismatched_sizes=True
    )
    
    # ⚡ TĂNG TỐC ĐỘ HỌC (Learning Rate) từ 1e-5 lên 2.5e-5 để AI chịu thay đổi góc nhìn
    learning_rate = 2.5e-5
    optimizer = tf.keras.optimizers.Adam(learning_rate=learning_rate)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])
    
    TOTAL_EPOCHS = 100
    print(f"\n🚀 SIÊU TỐC ĐỘ: Huấn luyện tối đa {TOTAL_EPOCHS} vòng cho đến khi Val_Accuracy bứt phá 45%")
    callbacks = [ThangDoVotNguong()]
    
    model.fit(
        train_inputs, train_labels_tf,
        validation_data=(val_inputs, val_labels_tf),
        epochs=TOTAL_EPOCHS,
        batch_size=8,
        callbacks=callbacks
    )
    
    # Lưu trọng số Stage 19
    current_output_dir = "checkpoint_stage19_Final"
    print(f"\n💾 Lưu bộ não Giao đoạn 19 vào: {current_output_dir}")
    model.save_pretrained(current_output_dir)
    print("💎 HOÀN THÀNH GIAI ĐOẠN 19! Trọng số đã lưu sẵn sàng cho Giao đoạn 20 - Huấn Luyện Sâu! 💎")

if __name__ == "__main__":
    main()
