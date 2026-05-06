import pandas as pd
from ghitav3_core import run_training_stage
import os

file_name = "stage1_words_standard.csv"
num_labels = pd.read_csv(file_name).iloc[:, 1].nunique()

print("="*50)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 1")
print("="*50)

run_training_stage(
    stage_num=1,
    data_file=file_name,
    epochs=500,
    learning_rate=2e-5,
    prev_model_path="google/mobilebert-uncased",
    current_output_dir="checkpoint_stage1",
    num_labels=num_labels,
    is_first_stage=True,
    is_final_stage=False
)
