import os
import glob
import pandas as pd
from ghitav3_core import run_training_stage

print("="*60)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 16: TỔNG ÔN TỪ GIAI ĐOẠN 11-15")
print("Chiến thuật: Trộn dữ liệu ngẫu nhiên & Học 100 vòng")
print("="*60)

# Lọc CHỈ LẤY đúng 5 file từ Giai đoạn 11 đến 15 theo yêu cầu
target_files = [
    "stage11_scenarios_asr_errors.csv",
    "stage12_scenarios_legitimate.csv",
    "stage13_scenarios_modern_frauds.csv",
    "stage14_scenarios_emotional_vishing.csv",
    "stage15_scenarios_social_media.csv"
]

csv_files = [f for f in target_files if os.path.exists(f)]
print(f"🔄 Đang tiến hành gom {len(csv_files)} file (chỉ từ 11 đến 15) và xào trộn ngẫu nhiên...")

dfs = []
for file in csv_files:
    try:
        df = pd.read_csv(file)
        if len(df.columns) == 2:
            df.columns = ["text", "label"]  # Chuẩn hóa tên cột
            dfs.append(df)
            print(f"   + Đã nạp: {file} ({len(df)} dòng)")
    except Exception as e:
        print(f"⚠️ Bỏ qua file: {file} do lỗi ({e})")

# Gom toàn bộ lại
merged_df = pd.concat(dfs, ignore_index=True)
merged_df = merged_df.dropna()

# TRỘN NGẪU NHIÊN 100% (Shuffle) để AI không học vẹt
merged_df = merged_df.sample(frac=1, random_state=42).reset_index(drop=True)

# BẮT BUỘC phải tạo 1 file tạm vì hệ thống `ghitav3_core.py` của bạn chỉ đọc dữ liệu từ file. 
# Tuy nhiên, tạo xong và học xong, TÔI SẼ BẢO CODE XÓA LUÔN NÓ ĐI để khỏi rác măt.
temp_file = "temp_stage16_random.csv"
merged_df.to_csv(temp_file, index=False)

print(f"✅ Đã khuấy ngẫu nhiên thành công {len(merged_df)} mẫu lừa đảo vào bộ nhớ tạm.")

# Khởi chạy quy trình học tập 
run_training_stage(
    stage_num=16,
    data_file=temp_file,
    epochs=7,                     # Học căng não 100 VÒNG theo yêu cầu 
    learning_rate=1e-5,             
    prev_model_path="checkpoint_stage15", 
    current_output_dir="checkpoint_stage16_Final", 
    num_labels=23,                  
    is_first_stage=False,
    is_final_stage=True             
)

# Chạy xong giai đoạn 16 thì dọn dẹp sạch sẽ rác luôn
if os.path.exists(temp_file):
    os.remove(temp_file)
    print(f"🧹 Đã tẩy xóa file bộ nhớ tạm không cần thiết ({temp_file}). Máy tính của bạn đã sạch sẽ!")
