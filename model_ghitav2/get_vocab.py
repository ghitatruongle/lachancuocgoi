from transformers import MobileBertTokenizer

tokenizer = MobileBertTokenizer.from_pretrained("google/mobilebert-uncased")
tokenizer.save_vocabulary(".")
print("✅ Đã trích xuất file vocab.txt chuẩn cho MobileBERT.")
