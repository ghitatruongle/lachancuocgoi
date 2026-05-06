import os
import shutil

# Đảm bảo mã hóa utf-8
os.environ["PYTHONIOENCODING"] = "utf-8"
os.environ["TF_USE_LEGACY_KERAS"] = "1"

from ghitav3_core import run_training_stage

def main():
    print("====================================================================")
    print("🚀 BẮT ĐẦU GIAI ĐOẠN 17: CHỐNG LẨN TRÁNH TEENCODE VÀ SCAM BỌC KẸO")
    print("====================================================================")
    
    # 1. Khởi chạy huấn luyện kế thừa checkpoint_stage16_Final
    run_training_stage(
        stage_num=17,
        data_file='stage17_scenarios_stealth_evasion.csv',
        epochs=15,          # Tăng biên độ vì train data nhiễu
        learning_rate=1e-5, # Học cực chậm tránh quên
        prev_model_path='checkpoint_stage16_Final',
        current_output_dir='checkpoint_stage17_Final',
        num_labels=23, 
        is_first_stage=False,
        is_final_stage=True # Sẽ kích hoạt xuất ghitav3_final.tflite
    )
    
    # 2. Đổi tên TFLite siêu cấp thành ghitav3_stealth_final.tflite
    if os.path.exists("ghitav3_final.tflite"):
        try:
            shutil.move("ghitav3_final.tflite", "ghitav3_stealth_final.tflite")
            print("💎 HOÀN THÀNH XUẤT SẮC! Đã chế tạo xong TFLite hoàn mĩ: ghitav3_stealth_final.tflite 💎")
        except Exception as e:
            print("Đã xuất ra ghitav3_final.tflite nhưng không thể rename do file đang mở:", e)
    else:
        print("Có lỗi trong quá trình xuất TFLite từ Stage 17.")

if __name__ == "__main__":
    main()
