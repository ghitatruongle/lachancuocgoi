import pandas as pd
from ghitav3_core import run_training_stage
import os

file_name = "stage6_phrases_dialects.csv"
num_labels = pd.read_csv(file_name).iloc[:, 1].nunique()

print("="*50)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 6")
print("="*50)

run_training_stage(
    stage_num=6,
    data_file=file_name,
    epochs=400,
    learning_rate=1e-5,
    prev_model_path="checkpoint_stage5",
    current_output_dir="checkpoint_stage6",
    num_labels=num_labels,
    is_first_stage=False,
    is_final_stage=False
)
