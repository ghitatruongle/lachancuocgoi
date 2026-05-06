import re

_re_special = re.compile(r'[^\w\s]')
_re_spaces = re.compile(r'\s+')

def clean_text(text: str) -> str:
    """
    Chuẩn hóa văn bản đầu vào:
    1. Chuyển thành chữ thường.
    2. Chỉ giữ lại chữ cái (cả tiếng Việt), số và khoảng trắng.
    3. Xóa các ký tự đặc biệt lừa đảo/cách chữ (., _ , *, -, /, ...).
    4. Gom chuỗi khoảng trắng dài thành 1 khoảng trắng duy nhất.
    """
    if not isinstance(text, str):
        return ""
        
    text = text.lower()
    # Loại bỏ hoàn toàn các ký tự không phải là chữ cái/số hoặc khoảng trắng
    text = _re_special.sub('', text)
    
    # \w bao gồm cả '_' nên ta xóa riêng ký tự '_'
    text = text.replace('_', '')
    
    # Gom khoảng trắng
    text = _re_spaces.sub(' ', text).strip()
    return text

if __name__ == "__main__":
    # Test cases
    samples = [
        "v.n.e.i.d khum m",
        "c..k luon di e",
        "a..l..o_ nhe",
        "p.h.ạ.t ng.u.o.i"
    ]
    for s in samples:
        print(f"Original: {s}")
        print(f"Cleaned : {clean_text(s)}\n")
