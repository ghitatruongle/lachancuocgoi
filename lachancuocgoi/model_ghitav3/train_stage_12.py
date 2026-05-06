import pandas as pd
from ghitav3_core import run_training_stage
import os

file_name = "stage12_scenarios_legitimate.csv"
num_labels = 23  # GhitaV3 luôn có đúng 23 class (nhãn 0-22), KHÔNG tự đếm từ CSV

print("="*50)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 12")
print("="*50)

run_training_stage(
    stage_num=12,
    data_file=file_name,
    epochs=20,
    learning_rate=1e-5,
    prev_model_path="checkpoint_stage11",
    current_output_dir="checkpoint_stage12",
    num_labels=num_labels,
    is_first_stage=False,
    is_final_stage=False
)
