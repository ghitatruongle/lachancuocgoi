import pandas as pd
from ghitav3_core import run_training_stage
import os

file_name = "stage4_words_south.csv"
num_labels = pd.read_csv(file_name).iloc[:, 1].nunique()

print("="*50)
print("KHỞI CHẠY HUẤN LUYỆN GIAI ĐOẠN 4")
print("="*50)

run_training_stage(
    stage_num=4,
    data_file=file_name,
    epochs=100,
    learning_rate=1e-5,
    prev_model_path="checkpoint_stage3",
    current_output_dir="checkpoint_stage4",
    num_labels=num_labels,
    is_first_stage=False,
    is_final_stage=False
)
