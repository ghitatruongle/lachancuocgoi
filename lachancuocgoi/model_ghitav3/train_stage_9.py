import pandas as pd
from ghitav3_core import run_training_stage
import os

file_name = "stage9_scenarios_standard.csv"
num_labels = pd.read_csv(file_name).iloc[:, 1].nunique()

print("="*50)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 9")
print("="*50)

run_training_stage(
    stage_num=9,
    data_file=file_name,
    epochs=100,
    learning_rate=2e-5,
    prev_model_path="checkpoint_stage8",
    current_output_dir="checkpoint_stage9",
    num_labels=num_labels,
    is_first_stage=False,
    is_final_stage=False
)
