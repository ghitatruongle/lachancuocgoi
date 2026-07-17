import csv
import itertools
import random
import os

# Số lượng mẫu mục tiêu cho mỗi nhãn (23 nhãn * 250 = 5750 dòng)
NUM_SAMPLES_PER_LABEL = 250
OUTPUT_FILE = "train_phothong.csv"

random.seed(42)

def generate_for_label(label, subjects, verbs, objects, standalone):
    """ Tạo dữ liệu tổ hợp câu, cụm từ cho 1 nhãn """
    results = []
    
    # Thêm luôn các cụm từ vựng đứng độc lập để AI nhận diện Keyword
    results.extend(standalone)
    results.extend(subjects)
    results.extend(verbs)
    results.extend(objects)
    
    # Tạo tổ hợp 2 thành phần (Câu ngắn)
    sv_pairs = list(itertools.product(subjects, verbs))
    vo_pairs = list(itertools.product(verbs, objects))
    
    for s, v in sv_pairs:
        results.append(f"{s} {v}")
    for v, o in vo_pairs:
        results.append(f"{v} {o}")
        
    # Tạo tổ hợp 3 thành phần (Câu dài hoàn chỉnh)
    svo_combos = list(itertools.product(subjects, verbs, objects))
    for s, v, o in svo_combos:
        results.append(f"{s} {v} {o}")
    
    # Làm sạch khoảng trắng thừa và ép chữ thường
    cleaned_results = [" ".join(text.split()) for text in results if len(text.strip()) > 0]
    
    # Xoá trùng lặp
    unique_results = list(set(cleaned_results))
    
    # Trộn ngẫu nhiên
    random.shuffle(unique_results)
    
    # Nếu thiếu số lượng, nhân bản và làm lệch một chút (nhưng với tổ hợp trên thì luôn dư rả)
    # Cắt lấy đúng số lượng cần thiết để cân bằng
    selected = unique_results[:NUM_SAMPLES_PER_LABEL]
    
    return [(text, label) for text in selected]

# Từ điển 23 nhãn tiếng Việt phổ thông (chuẩn ngữ pháp)
data_dict = {
    0: { # Tòa án, Công an
        "subjects": ["cơ quan công an", "cảnh sát điều tra", "viện kiểm sát", "tòa án nhân dân", "bộ công an", "cục cảnh sát hình sự"],
        "verbs": ["thông báo", "yêu cầu", "đề nghị", "triệu tập", "ra lệnh", "cảnh báo", "tiến hành khởi tố"],
        "objects": ["phối hợp làm việc", "trình diện", "về chuyên án rửa tiền", "vì liên quan đến đường dây ma túy", "chứng minh sự vô tội", "hợp tác điều tra", "cung cấp thông tin tài chính"],
        "standalone": ["lệnh bắt tạm giam", "chiếm đoạt tài sản", "tội phạm xuyên quốc gia", "buôn lậu"]
    },
    1: { # Thuế, VNeID, Công dịch vụ
        "subjects": ["cục thuế", "tổng cục thuế", "cơ quan dịch vụ công", "hệ thống định danh điện tử", "cán bộ phường", "cơ sở dữ liệu dân cư"],
        "verbs": ["yêu cầu", "đề nghị", "thông báo", "hướng dẫn", "cập nhật", "đồng bộ"],
        "objects": ["tài khoản VNeID mức hai", "dữ liệu sinh trắc học", "thông tin căn cước công dân gắn chíp", "quyết toán thuế thu nhập cá nhân", "nộp phạt vi phạm hành chính"],
        "standalone": ["dịch vụ công", "hoàn thuế", "kê khai thuế", "ứng dụng thuế điện tử"]
    },
    2: { # Nhà mạng, Sim
        "subjects": ["nhà mạng viễn thông", "trung tâm viễn thông", "hệ thống chăm sóc khách hàng", "bộ thông tin và truyền thông", "tổng đài chăm sóc khách hàng"],
        "verbs": ["thông báo", "cảnh báo", "sẽ tiến hành", "quyết định", "yêu cầu"],
        "objects": ["khóa sim hai chiều", "thu hồi số điện thoại", "chuẩn hóa thông tin thuê bao", "đăng ký chính chủ sim", "xử lý nợ cước quốc tế", "ngừng cung cấp dịch vụ viễn thông"],
        "standalone": ["phát tán tin nhắn rác", "chuyển đổi mạng giữ số", "cập nhật thuê bao"]
    },
    3: { # Mạng xã hội, Hack tài khoản
        "subjects": ["hệ thống mạng xã hội", "tài khoản thư điện tử", "bộ phận hỗ trợ kỹ thuật", "trung tâm bảo mật", "nền tảng truyền thông"],
        "verbs": ["phát hiện", "cảnh báo", "yêu cầu", "khóa", "tạm ngưng", "bảo vệ"],
        "objects": ["đăng nhập bất thường từ thiết bị lạ", "khôi phục mật khẩu tài khoản", "cung cấp mã xác nhận hai lớp", "hành vi vi phạm tiêu chuẩn cộng đồng", "ảnh đại diện giả mạo"],
        "standalone": ["mã OTP", "xác minh danh tính", "hacker tấn công", "lấy lại quyền truy cập"]
    },
    4: { # Y tế, Cấp cứu
        "subjects": ["bệnh viện đa khoa", "phòng cấp cứu", "bác sĩ chuyên khoa", "nhân viên y tế", "trung tâm y tế cấp cứu"],
        "verbs": ["thông báo", "yêu cầu", "đề nghị khẩn cấp", "chuẩn bị tiến hành", "cần gấp"],
        "objects": ["chuyển khoản tạm ứng viện phí", "phẫu thuật khẩn cấp cho bệnh nhân", "xử lý chấn thương sọ não do tai nạn giao thông", "đóng tiền mua thuốc đặc trị", "cấp cứu tình trạng nguy kịch"],
        "standalone": ["bảo hiểm y tế", "ứng trước tiền thuốc", "hồ sơ bệnh án", "nhóm máu hiếm"]
    },
    5: { # Bắt cóc, đe dọa
        "subjects": ["tổ chức tội phạm", "nhóm bắt cóc", "đối tượng xấu", "người giấu mặt"],
        "verbs": ["yêu cầu", "đe dọa", "bắt giữ", "cảnh báo", "ép buộc", "ra điều kiện"],
        "objects": ["giao nộp tiền chuộc", "giữ người trái phép", "đe dọa tính mạng người thân", "nếu báo công an sẽ không đảm bảo an toàn", "chuyển tiền ngay lập tức"],
        "standalone": ["camera giám sát", "hành vi bạo lực", "đừng hòng thấy mặt", "không được lên tiếng"]
    },
    6: { # Sếp, chuyển tiền
        "subjects": ["giám đốc điều hành", "tổng giám đốc", "trưởng phòng kinh doanh", "kế toán trưởng", "ban lãnh đạo công ty"],
        "verbs": ["chỉ đạo", "yêu cầu", "đề nghị", "giao nhiệm vụ", "thông báo khẩn"],
        "objects": ["chuyển khoản cho đối tác chiến lược", "tạm ứng quỹ ngoại giao", "thực hiện giao dịch bí mật", "thanh toán hợp đồng dự án", "huy động vốn nội bộ", "chuyển tiền vào tài khoản cá nhân"],
        "standalone": ["thương vụ đầu tư", "chuyển tiền ngay", "báo cáo tài chính"]
    },
    7: { # Mượn tiền người quen
        "subjects": ["người quen", "bạn học cũ", "đồng nghiệp cũ", "hàng xóm", "người thân trong gia đình"],
        "verbs": ["ngỏ ý", "nhờ vả", "đề nghị", "liên hệ", "xin phép"],
        "objects": ["mượn tiền giải quyết việc gấp", "vay tạm một khoản tiền nhỏ", "chuyển khoản thanh toán hóa đơn hộ", "trợ giúp trong lúc khó khăn đột xuất"],
        "standalone": ["quên mang ví", "thiếu tiền đổ xăng", "vay tạm", "trả lại vào ngày mai"]
    },
    8: { # Quà nước ngoài, hải quan
        "subjects": ["cục hải quan", "nhân viên sân bay", "công ty vận tải quốc tế", "người bạn ngoại quốc", "kỹ sư dầu khí"],
        "verbs": ["gửi", "thông báo", "yêu cầu", "đề nghị nộp", "giữ lại"],
        "objects": ["bưu kiện hàng hóa từ nước ngoài", "đóng phí vận chuyển và lưu kho", "quà tặng có giá trị cao", "tiền thuế nhập khẩu vật phẩm", "thủ tục thông quan hàng hóa"],
        "standalone": ["đồng đô la mỹ", "kiện hàng kẹt lại", "trang sức quý giá"]
    },
    9: { # Đe dọa ảnh nóng
        "subjects": ["kẻ tống tiền", "hacker ẩn danh", "đối tượng đe dọa", "nhóm tội phạm mạng"],
        "verbs": ["nắm giữ", "phát tán", "đe dọa công khai", "yêu cầu trả", "sẽ gửi cho"],
        "objects": ["hình ảnh nhạy cảm cá nhân", "video và tài liệu đồi trụy", "phí bảo mật để xóa dữ liệu", "đồng nghiệp và gia đình", "đăng tải lên mạng xã hội"],
        "standalone": ["giữ bí mật", "xóa dấu vết", "thời gian đếm ngược"]
    },
    10: { # Từ thiện
        "subjects": ["quỹ bảo trợ trẻ em", "tổ chức chữ thập đỏ", "ban vận động cứu trợ", "nhà hảo tâm", "mặt trận tổ quốc", "nhóm từ thiện"],
        "verbs": ["kêu gọi", "phát động", "nhận", "mong muốn", "quyên góp"],
        "objects": ["ủng hộ đồng bào bị lũ lụt", "giúp đỡ trẻ em nghèo vùng cao", "xây dựng trường học và trạm y tế", "hỗ trợ hoàn cảnh khó khăn", "cung cấp bữa cơm tình thương"],
        "standalone": ["mạnh thường quân", "lòng nhân ái", "số tài khoản quyên góp"]
    },
    11: { # Đầu tư tài chính
        "subjects": ["sàn giao dịch chứng khoán", "chuyên gia phân tích tài chính", "nền tảng đầu tư tiền điện tử", "nhóm hỗ trợ đầu tư VIP"],
        "verbs": ["mời tham gia", "cam kết", "hứa hẹn", "đảm bảo", "khuyến nghị"],
        "objects": ["mức lợi nhuận khổng lồ", "đầu tư không có rủi ro", "giao dịch tự động sinh lời", "cổ phiếu có tiềm năng tăng trưởng mạnh", "đọc lệnh thị trường ngoại hối"],
        "standalone": ["tiền ảo", "lãi suất kép", "thu hồi vốn", "vàng trực tuyến"]
    },
    12: { # Tuyển dụng việc làm
        "subjects": ["công ty thương mại điện tử", "đại lý mua sắm trực tuyến", "nhà tuyển dụng", "nền tảng truyền thông"],
        "verbs": ["cần tuyển", "tìm kiếm", "cam kết", "hỗ trợ", "trả công"],
        "objects": ["cộng tác viên làm việc tại nhà", "thực hiện thao tác chốt đơn hàng ảo", "nhiệm vụ đánh giá sản phẩm trực tuyến", "nhập dữ liệu không giới hạn thời gian", "tăng lượt theo dõi mạng xã hội"],
        "standalone": ["hoa hồng thanh toán theo ngày", "việc nhẹ lương cao", "chỉ cần điện thoại"]
    },
    13: { # Trúng thưởng
        "subjects": ["chương trình tri ân khách hàng", "ban tổ chức sự kiện", "hệ thống quay số trúng thưởng", "bộ phận chăm sóc khách hàng", "nhà tài trợ"],
        "verbs": ["thông báo", "chúc mừng", "trao tặng", "yêu cầu cung cấp", "xác nhận"],
        "objects": ["giải thưởng đặc biệt có giá trị lớn", "điện thoại thông minh cao cấp", "chuyến du lịch nghỉ dưỡng trọn gói", "đóng lệ phí để nhận giải", "mã số dự thưởng trùng khớp"],
        "standalone": ["nhận quà miễn phí", "phiếu mua hàng", "giao thưởng tận nhà"]
    },
    14: { # Soi cầu
        "subjects": ["trung tâm soi cầu", "chuyên gia tính toán xác suất", "nhóm dự đoán kết quả", "phần mềm giải mã"],
        "verbs": ["cung cấp", "chốt", "đảm bảo", "nuôi", "dự báo"],
        "objects": ["kết quả xổ số thống kê chính xác", "con số may mắn độc đắc", "bạch thủ lô đề", "tỷ lệ trúng thưởng tuyệt đối", "cầu đẹp về trong ngày"],
        "standalone": ["về bờ an toàn", "số nội bộ", "giải đặc biệt"]
    },
    15: { # Xuất khẩu lao động
        "subjects": ["công ty tư vấn di trú", "đại lý xuất khẩu lao động", "cơ quan hỗ trợ du học", "chương trình định cư"],
        "verbs": ["cam kết", "hỗ trợ", "cung cấp", "yêu cầu nộp", "đảm bảo tiến độ"],
        "objects": ["thủ tục làm visa nhanh chóng", "cơ hội bảo lãnh định cư tại châu âu", "chi phí trọn gói xuất cảnh", "không cần chứng minh năng lực tài chính", "hồ sơ ngoại ngữ và kỹ năng"],
        "standalone": ["thực tập sinh", "visa du lịch", "thu nhập vượt trội"]
    },
    16: { # Ngân hàng
        "subjects": ["ngân hàng thương mại", "hệ thống thẻ tín dụng", "trung tâm bảo mật tài khoản", "chi nhánh ngân hàng"],
        "verbs": ["thông báo", "cảnh báo", "yêu cầu", "đề nghị", "tự động khóa"],
        "objects": ["phát sinh giao dịch thanh toán bất thường", "nâng cấp hạn mức cho vay thấu chi", "xác nhận mã bảo mật cá nhân", "cập nhật chữ ký số", "kiểm tra số dư hiện tại"],
        "standalone": ["mã OTP", "thẻ ATM", "dịch vụ Internet Banking"]
    },
    17: { # Shipper
        "subjects": ["bưu điện trung tâm", "nhân viên giao nhận", "công ty chuyển phát nhanh", "trung tâm vận tải bưu chính"],
        "verbs": ["gửi", "thông báo", "yêu cầu", "thu hộ", "xử lý"],
        "objects": ["kiện hàng đã bị thất lạc", "tiền mặt thanh toán khi nhận hàng", "phí hoàn trả do sai địa chỉ", "đơn hàng bị hư hỏng do vận chuyển", "ủy quyền nhận biên lai bưu phẩm"],
        "standalone": ["chuyển khoản cọc trước", "giao hàng tận nơi", "mã vận đơn"]
    },
    18: { # Trừ tiền
        "subjects": ["dịch vụ ứng dụng giải trí", "nền tảng phần mềm", "hệ thống lưu trữ đám mây", "nhà cung cấp viễn thông"],
        "verbs": ["tự động", "tiến hành", "thông báo", "yêu cầu", "áp dụng"],
        "objects": ["trừ tiền gia hạn gói cước hàng tháng", "hủy đăng ký dịch vụ để tránh phát sinh", "chi phí duy trì bảo hiểm sức khỏe", "thanh toán định kỳ hóa đơn tiện ích", "thu phí ứng dụng đọc báo"],
        "standalone": ["gói dữ liệu tốc độ cao", "dịch vụ VIP", "hợp đồng tự động"]
    },
    19: { # Đòi nợ
        "subjects": ["văn phòng thu hồi nợ", "tổ chức tín dụng đen", "nhóm đòi nợ thuê", "chủ nợ"],
        "verbs": ["cảnh cáo", "đòi", "tiến hành", "đe dọa", "áp dụng biện pháp"],
        "objects": ["thanh toán số nợ quá hạn gốc và lãi", "khủng bố danh bạ điện thoại", "báo cáo thông tin nợ xấu lên hệ thống", "xử lý theo quy định của pháp luật", "siết nợ và phong tỏa tài sản"],
        "standalone": ["trốn nợ", "áp lực trả tiền", "khoản vay tiêu dùng"]
    },
    20: { # Lấy lại tiền
        "subjects": ["văn phòng luật sư chuyên nghiệp", "đội đặc nhiệm công nghệ cao", "chuyên gia an ninh mạng", "tổ chức hỗ trợ pháp lý"],
        "verbs": ["cam kết", "cung cấp", "giúp đỡ", "yêu cầu nộp", "thực hiện"],
        "objects": ["lấy lại toàn bộ số tiền bị lừa đảo", "truy vết dòng tiền qua các ví điện tử", "khôi phục tài sản qua phần mềm nội bộ", "phí xử lý hồ sơ kiện tụng ban đầu", "phong tỏa tài khoản của tội phạm"],
        "standalone": ["hacker thu hồi", "đòi lại công bằng", "chiếm đoạt không gian mạng"]
    },
    21: { # Hội thảo / Dịch vụ ảo
        "subjects": ["ban tổ chức hội thảo", "câu lạc bộ doanh nhân", "nền tảng khóa học trực tuyến", "các nhà đầu tư chuyên nghiệp"],
        "verbs": ["kính mời", "chia sẻ", "đăng ký", "nâng cấp", "thanh toán"],
        "objects": ["tham gia sự kiện chuyển đổi số", "chi phí để truy cập gói tài liệu đặc biệt", "bí quyết kinh doanh thành công", "chứng nhận hoàn thành chương trình", "cơ hội nâng cấp phiên bản phần mềm doanh nghiệp"],
        "standalone": ["nhà đầu tư thiên thần", "khóa học kinh doanh", "cơ hội độc quyền"]
    },
    22: { # Giao tiếp thông thường
        "subjects": ["tôi", "người đồng nghiệp", "thành viên gia đình", "bạn bè thân thiết", "nhân viên hành chính"],
        "verbs": ["hỏi thăm", "thông báo", "xác nhận", "nhắc nhở", "chúc mừng"],
        "objects": ["lịch trình cuộc họp giao ban sáng nay", "kết thúc dự án một cách thành công", "tình hình sức khỏe thời gian qua", "kế hoạch đi ăn tối cùng gia đình", "nội dung báo cáo công việc tuần"],
        "standalone": ["hẹn gặp lại", "chào buổi sáng", "xin cảm ơn"]
    }
}

full_dataset = []

for label, components in data_dict.items():
    dataset_l = generate_for_label(
        label=label, 
        subjects=components["subjects"], 
        verbs=components["verbs"], 
        objects=components["objects"], 
        standalone=components["standalone"]
    )
    full_dataset.extend(dataset_l)

# Trộn toàn bộ dữ liệu lần cuối
random.shuffle(full_dataset)

# Ghi ra file CSV
with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    f.write("text,label\n")
    for text, label in full_dataset:
        # Wrap everything in quotes to handle any potential commas
        f.write(f'"{text}",{label}\n')

print(f"Đã tạo thành công {len(full_dataset)} dòng vào {OUTPUT_FILE}!")
