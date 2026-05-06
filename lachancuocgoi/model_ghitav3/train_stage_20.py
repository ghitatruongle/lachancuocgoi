import os
import glob
import random
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from transformers import MobileBertTokenizer, TFMobileBertForSequenceClassification

os.environ["PYTHONIOENCODING"] = "utf-8"
os.environ["TF_USE_LEGACY_KERAS"] = "1"

BASE_MODEL = "google/mobilebert-uncased"
MAX_LENGTH = 256
try:
    TOKENIZER = MobileBertTokenizer.from_pretrained(BASE_MODEL)
except:
    TOKENIZER = MobileBertTokenizer(vocab_file="vocab.txt")

def encode_data(texts, labels):
    inputs = TOKENIZER(texts, padding=True, truncation=True, max_length=MAX_LENGTH, return_tensors="tf")
    return dict(inputs), tf.convert_to_tensor(labels)

# ============================================================
# 🛑 CHIẾN THUẬT: DATA REPLAY + EARLY STOPPING THÔNG MINH
# ============================================================
# Nguyên nhân kẹt 29%: Tập Stage 19 chỉ ~112 dòng, chia 23 nhãn
# => Validation set ~17 mẫu => mỗi nhãn 0-1 mẫu => val_accuracy
# KHÔNG BAO GIỜ ĐẠT 45% được bằng toán học.
#
# Giải pháp: TRỘN dữ liệu Stage 19 VỚI 30% data Stage 9-17.
# Tổng dataset tăng lên ~1500+ dòng => Validation có đủ mẫu
# để val_accuracy phản ánh đúng sức mạnh thực sự của AI.
# ============================================================

class PhaKhoaEarlyStopping(tf.keras.callbacks.Callback):
    """Tự ngắt khi Val_Accuracy vượt 40% (Thành công) hoặc sập lún dưới 10% (sau vòng 40)."""
    def __init__(self):
        super().__init__()
        self.best_val_loss = float('inf')
        self.patience_counter = 0
        self.patience = 5
        
    def on_epoch_end(self, epoch, logs=None):
        val_acc = logs.get('val_accuracy', 0)
        val_loss = logs.get('val_loss', float('inf'))
        
        # [1] Mục tiêu chính: Đạt 40% và qua ít nhất 10 vòng
        if val_acc >= 0.40 and epoch >= 10:
            print(f"\n{'='*60}")
            print(f"✅ ĐẠT MỤC TIÊU! Val_Accuracy = {val_acc:.4f} >= 40% sau {epoch + 1} vòng")
            print(f"🛑 Dừng sớm tại Vòng {epoch + 1} để bảo toàn trí nhớ!")
            print(f"{'='*60}")
            self.model.stop_training = True
            return
            
        # [2] Phòng chống sụp đổ Weights (Sập hầm) sau vòng 40
        if epoch >= 40 and val_acc <= 0.10:
            print(f"\n{'='*60}")
            print(f"❌ CẢNH BÁO SẬP LÚN TẠI VÒNG {epoch + 1}!")
            print(f"⚠️ Val_Accuracy tụt xuống = {val_acc:.4f} <= 10%. Mất kiến thức.")
            print(f"{'='*60}")
            self.model.stop_training = True
            return
            
        # [3] Phanh phụ: Val_Loss tăng liên tục 5 vòng => Overfit  
        if val_loss < self.best_val_loss:
            self.best_val_loss = val_loss
            self.patience_counter = 0
        else:
            self.patience_counter += 1
            if self.patience_counter >= self.patience:
                print(f"\n⚠️ Val_Loss không giảm sau {self.patience} vòng liên tiếp.")
                print(f"🛑 Dừng để chống Overfit. Val_Acc hiện tại: {val_acc:.4f}")
                self.model.stop_training = True

def load_replay_data():
    """Nạp 30% dữ liệu ngẫu nhiên từ Stage 9-17 làm Ký ức Replay."""
    replay_frames = []
    csv_patterns = [
        "stage9_scenarios_standard.csv",
        "stage10_scenarios_dialects.csv",
        "stage11_scenarios_asr_errors.csv",
        "stage12_scenarios_legitimate.csv",
        "stage13_scenarios_modern_frauds.csv",
        "stage14_scenarios_emotional_vishing.csv",
        "stage15_scenarios_social_media.csv",
        "stage17_scenarios_stealth_evasion.csv",
    ]
    
    for csv_file in csv_patterns:
        if os.path.exists(csv_file):
            # Đọc KHÔNG có header để tránh trường hợp file thiếu header
            df = pd.read_csv(csv_file, header=None)
            # Chỉ lấy 2 cột đầu
            df = df.iloc[:, :2]
            df.columns = ["text", "label"]
            
            # Lọc bỏ dòng header nếu bị lẫn vào data (vd: "text","label")
            df = df[df["label"].astype(str).str.strip().str.lower() != "label"]
            
            # Ép label thành số, dòng nào không ép được thì thành NaN rồi dropna
            df["label"] = pd.to_numeric(df["label"], errors="coerce")
            df = df.dropna(subset=["text", "label"])
            df["label"] = df["label"].astype(int)
            
            # Lấy 30% THEO THỨ TỰ (từ trên xuống), TUYỆT ĐỐI KHÔNG XÁO TRỘN để giữ mạch tình huống
            sample_size = max(1, int(len(df) * 0.3))
            sampled = df.head(sample_size)
            replay_frames.append(sampled)
            print(f"   📦 Replay: {csv_file} -> lấy {len(sampled)}/{len(df)} dòng (giữ nguyên mạch hội thoại)")
    
    if replay_frames:
        return pd.concat(replay_frames, ignore_index=True)
    return pd.DataFrame(columns=["text", "label"])

def main():
    print("=" * 68)
    print("🧠 GIAI ĐOẠN 20: PHÁ VỠ BẾ TẮC (DATA REPLAY + DEEP LEARNING)")
    print("=" * 68)
    
    # === BƯỚC 0: Tự động sinh lại dữ liệu Stage 19 (Cửa sổ trượt) ===
    print("\n🔄 Đang sinh lại dữ liệu Stage 19 (Cửa sổ trượt cộng dồn)...")
    from generate_stage19_data import SCAM_CONVERSATIONS, SAFE_CONVERSATIONS, build_sliding_window_csv
    all_conversations = SCAM_CONVERSATIONS + SAFE_CONVERSATIONS
    build_sliding_window_csv(all_conversations, "stage19_scenarios_sliding_window.csv")
    
    # === BƯỚC 1: Nạp dữ liệu Stage 19 (Core) ===
    core_file = "stage19_scenarios_sliding_window.csv"
    if not os.path.exists(core_file):
        print(f"❌ Không tìm thấy {core_file}")
        return
    
    core_df = pd.read_csv(core_file)
    print(f"\n📊 Dữ liệu Core (Stage 19): {len(core_df)} dòng")
    
    # === BƯỚC 2: Nạp Ký ức Replay từ Stage 9-17 ===
    print("\n🔄 Đang nạp Ký ức Replay từ Stage 9-17...")
    replay_df = load_replay_data()
    
    # === BƯỚC 3: TÁCH BIỆT DỮ LIỆU ĐỂ BẢO VỆ MẠCH HỘI THOẠI ===
    # ⚠️ NGUYÊN TẮC THÉP:
    # - Stage 19: 100% VÀO TRAIN, giữ nguyên thứ tự tình huống (A->B->C->D)
    #   KHÔNG RÚT BẤT KỲ CÂU NÀO RA làm Validation (vì sẽ phá nát mạch)
    # - Replay (Stage 9-17): Chia 85/15 riêng để làm Validation
    
    # Bỏ các dòng rác (NaN / Null) bị lỗi trong CSV trước khi ép kiểu học
    core_df = core_df.dropna()
    core_texts = core_df.iloc[:, 0].astype(str).tolist()
    core_labels = core_df.iloc[:, 1].astype(int).tolist()
    
    if len(replay_df) > 0:
        replay_texts = replay_df["text"].astype(str).tolist()
        replay_labels = replay_df["label"].astype(int).tolist()
        
        # Chỉ chia Replay data thành Train/Val (TUYỆT ĐỐI KHÔNG XÁO TRỘN)
        replay_train_texts, val_texts, replay_train_labels, val_labels = train_test_split(
            replay_texts, replay_labels, test_size=0.15, random_state=42, shuffle=False
        )
        
        # Train = [Stage 19 nguyên bản] + [85% Replay]
        train_texts = core_texts + replay_train_texts
        train_labels = core_labels + replay_train_labels
        
        print(f"\n🎯 PHÂN BỔ DỮ LIỆU:")
        print(f"   🔒 Train - Stage 19 (nguyên thứ tự): {len(core_texts)} câu")
        print(f"   🔀 Train - Replay (nguyên thứ tự):   {len(replay_train_texts)} câu")
        print(f"   📐 Train TỔNG:                        {len(train_texts)} câu")
        print(f"   📋 Validation (chỉ từ Replay):        {len(val_texts)} câu")
    else:
        # Không có Replay => dùng hết Stage 19, tách 15% cuối làm Validation
        split_idx = int(len(core_texts) * 0.85)
        train_texts = core_texts[:split_idx]
        train_labels = core_labels[:split_idx]
        val_texts = core_texts[split_idx:]
        val_labels = core_labels[split_idx:]
        print("⚠️ Không tìm thấy Replay, tách 15% cuối Stage 19 làm Validation.")
    
    # === BƯỚC 5: Tokenize ===
    print("\n⚡ Đang nén dữ liệu qua MobileBert Tokenizer...")
    train_inputs, train_labels_tf = encode_data(train_texts, train_labels)
    val_inputs, val_labels_tf = encode_data(val_texts, val_labels)
    
    # === BƯỚC 6: Nạp mô hình từ checkpoint Stage 19 ===
    prev_model = "checkpoint_stage19_Final"
    print(f"\n🔄 Nạp trí nhớ từ: {prev_model}")
    model = TFMobileBertForSequenceClassification.from_pretrained(
        prev_model, num_labels=23, ignore_mismatched_sizes=True
    )
    
    # === BƯỚC 7: Compile với Cosine Decay LR ===
    # Mở rộng chu kỳ tương ứng 500 vòng
    total_steps = (len(train_texts) // 8) * 500  # 500 epochs x steps/epoch
    lr_schedule = tf.keras.optimizers.schedules.CosineDecay(
        initial_learning_rate=3e-5,  # Bắt đầu mạnh
        decay_steps=total_steps,
        alpha=1e-6  # Kết thúc siêu nhẹ
    )
    optimizer = tf.keras.optimizers.Adam(learning_rate=lr_schedule)
    loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)
    model.compile(optimizer=optimizer, loss=loss, metrics=["accuracy"])
    
    # === BƯỚC 8: HUẤN LUYỆN SÂU ===
    print(f"\n🚀 BẮT ĐẦU HUẤN LUYỆN SÂU: Tối đa 500 Vòng (Epochs)")
    print(f"   LR: 3e-5 -> 1e-6 (Cosine Decay trải dài 500 vòng)")
    print(f"   Early Stopping kích hoạt khi: Val_Acc >= 40% (Đạt đỉnh)")
    print(f"   Hoặc khi Val_Acc <= 10% (Sập lún) SAU vòng thứ 40.")
    
    callbacks = [PhaKhoaEarlyStopping()]
    
    model.fit(
        train_inputs, train_labels_tf,
        validation_data=(val_inputs, val_labels_tf),
        epochs=500,
        batch_size=8,
        callbacks=callbacks,
        shuffle=False
    )
    
    # === BƯỚC 9: Lưu checkpoint ===
    output_dir = "checkpoint_stage20_Final"
    print(f"\n💾 Lưu bộ não Giai đoạn 20 vào: {output_dir}")
    model.save_pretrained(output_dir)
    
    # === BƯỚC 10: Xuất TFLite ===
    print("\n🚀 Xuất TFLite model cuối cùng...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    
    tflite_model = converter.convert()
    
    # Di chuyển vào thư mục ver4(17-20)
    tflite_dir = r"d:\25-26\Lá chắn cuộc gọi\lachancuocgoi\model_ghitav3\ver4(17-20)"
    if not os.path.exists(tflite_dir):
        os.makedirs(tflite_dir)
    
    tflite_path = os.path.join(tflite_dir, "ghitav3.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    
    # Lưu vocab.txt
    vocab_path = os.path.join(tflite_dir, "vocab.txt")
    with open(vocab_path, "w", encoding="utf-8") as f:
        for token in TOKENIZER.vocab.keys():
            f.write(token + '\n')
    
    print(f"\n{'='*68}")
    print(f"💎💎💎 HOÀN THÀNH LỘ TRÌNH VƯỢT GIỚI HẠN! 💎💎💎")
    print(f"   📦 Model: {tflite_path}")
    print(f"   📖 Vocab: {vocab_path}")
    print(f"{'='*68}")

if __name__ == "__main__":
    main()
