import sys
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass
import os
import random
import numpy as np
import tensorflow as tf
from transformers import MobileBertTokenizer, TFAutoModelForSequenceClassification

os.environ["TF_USE_LEGACY_KERAS"] = "1"

# TỐI ƯU HÓA CPU: Dùng 10/12 luồng cho các tính toán song song
tf.config.threading.set_intra_op_parallelism_threads(10)
tf.config.threading.set_inter_op_parallelism_threads(10)

# ============================================================
# CẤU HÌNH PHẦN CỨNG (GPU / CPU)
# ============================================================
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        # Ép ăn tối đa 4GB VRAM (4096 MB) để GPU nhàn rỗi hơn nhưng vẫn load model siêu nhanh
        tf.config.experimental.set_virtual_device_configuration(
            gpus[0],
            [tf.config.experimental.VirtualDeviceConfiguration(memory_limit=4096)])
        print("🚀 Đã tìm thấy và bật GPU Hardware Acceleration!")
    except RuntimeError as e:
        print(e)
else:
    print("💻 Không tìm thấy GPU, hệ thống sẽ chạy bằng CPU.")

print("="*80)
print("ĐÁNH GIÁ TỔNG HỢP 500 KỊCH BẢN (4 PHIÊN BẢN — OOD + GEN-Z + HARD NEGATIVES)")
print("="*80)

vocab_path = "vocab.txt"
if not os.path.exists(vocab_path):
    print("❌ Lỗi: Không tìm thấy 'vocab.txt'.")
    exit(1)

TOKENIZER = MobileBertTokenizer(vocab_file=vocab_path, local_files_only=True)
MAX_LEN = 256

def load_tflite_model(model_path):
    # Kích hoạt 10 luồng xử lý CPU trực tiếp cho TFLite Interpreter
    interpreter = tf.lite.Interpreter(model_path=model_path, num_threads=10)
    for detail in interpreter.get_input_details():
        interpreter.resize_tensor_input(detail['index'], [1, MAX_LEN])
    interpreter.allocate_tensors()
    return interpreter

def predict_tflite(interpreter, text):
    inputs = TOKENIZER(text, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="np")
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    for detail in input_details:
        name = detail['name'].lower()
        if 'input_ids' in name:
            interpreter.set_tensor(detail['index'], inputs['input_ids'].astype(np.int32))
        elif 'attention_mask' in name:
            interpreter.set_tensor(detail['index'], inputs['attention_mask'].astype(np.int32))
        elif 'token_type_ids' in name:
            interpreter.set_tensor(detail['index'], inputs['token_type_ids'].astype(np.int32))
            
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    probs = tf.nn.softmax(output[0]).numpy()
    pred_class = np.argmax(probs)
    return pred_class, probs[pred_class] * 100

def load_hf_model(model_path):
    return TFAutoModelForSequenceClassification.from_pretrained(model_path)

def predict_hf(model, text):
    inputs = TOKENIZER(text, padding="max_length", truncation=True, max_length=MAX_LEN, return_tensors="tf")
    outputs = model(**inputs)
    probs = tf.nn.softmax(outputs.logits[0]).numpy()
    pred_class = np.argmax(probs)
    return pred_class, probs[pred_class] * 100

# ============================================================================
# 4 PHIÊN BẢN MODEL VER7
# ============================================================================
paths = {
    "Ver7 (Stage 31)": ("tflite", r"ver7(30-34)\30-31\ghitav3.tflite"),
    "Ver7 (Stage 32)": ("tflite", r"ver7(30-34)\32\ghitav3.tflite"),
    "Ver7 (Stage 33)": ("tflite", r"ver7(30-34)\33\ghitav3.tflite"),
    "Ver7 (Stage 34)": ("tflite", r"ver7(30-34)\34\ghitav3.tflite"),
}

models = {}
for ten, (mtype, path) in paths.items():
    if os.path.exists(path):
        if mtype == "tflite":
            models[ten] = ("tflite", load_tflite_model(path))
        else:
            models[ten] = ("hf", load_hf_model(path))
        print(f"  ✅ Đã sẵn sàng: {ten}")
    else:
        print(f"  ❌ THIẾU TỆP THỰC: Tập tin '{path}' không tồn tại.")

if len(models) == 0:
    exit(1)

scenarios = [
    ("Alo, tôi là cán bộ công an giao thông. Anh bị phạt nguội 5 triệu, đề nghị chuyển khoản ngay.", 0),
    ("Tôi ở phòng cảnh sát hình sự. Số CMT của anh liên quan đường dây rửa tiền xuyên quốc gia.", 0),
    ("Chào anh, tòa án gửi giấy triệu tập. Để hoãn xử lý, yêu cầu đóng 20 triệu.", 0),
    ("Tớ là công an khu vực, yêu cầu chuyển 2 triệu phí đăng ký tạm trú nếu không cắt hộ khẩu.", 0),
    ("ê m ơi can hs gọi m bị ph4t nguoi kià, ck lẹ lẹ đi khum nó bế đi á", 0),
    ("tưởng m làm c0ng 4n oai lắm nay xộ khám r nha, c.k tiền vô đây t gỡ tội cho, ét ô ét!!", 0),
    ("mãi keo vs anh giao thông nên bị quất cái biên lai phạt 5 củ đó m, ck cho tk bạc lẹ đi m ơi", 0),
    ("alo tui can nè, mi bị phat nguội, nộp phat 2 trieu qua stk nay nha", 0),
    ("SOS t bị can gọi báo có dính ma tuý nó đòi 50 củ bảo lãnh, lo vãi chưởng", 0),
    ("Anh vui lòng truy cập đường link dvc.gov.vn.apk để cài đặt ứng dụng VNeID mới nhất.", 1),
    ("Tài khoản bị lỗi sinh trắc học, yêu cầu cấp quyền trợ năng để em đồng bộ khuôn mặt.", 1),
    ("do sáp nhập xã nên sổ hộ khẩu bị khóa, chị cài app này để mở lại nhé.", 1),
    ("Cảnh sát yêu cầu xác thực VNeID online, gọi video share màn hình giúp em.", 1),
    ("cán pộ ép cài cái app vne1d gì đó, đòi share màn hình nữa chằm zn thiệt", 1),
    ("ê click vô cái link vnẹid này đi để update khuôn mặt khum là mốt nó khoá cccd đó m", 1),
    ("tầm này ai tải v.n.e.i.đ trên store nữa, down file apk này ấp đết xịn đét 100%", 1),
    ("vneid của ẻm bị lag r nè, báo phai share man hinh gap", 1),
    ("alo tui làm bên dvc ne, acc ô bị khoá r, tải app cap quyen tro nang dum", 1),
    ("Vietcombank thông báo: Tài khoản đang bị đăng nhập trái phép. Bấm link để đổi mật khẩu.", 16),
    ("Số dư thẻ anh chị bị trừ khoản 15 triệu, đọc OTP để chúng tôi hủy giao dịch.", 16),
    ("NHNN yêu cầu liên kết Momo với ATM để nhận gói covid, đọc mã xác thực 6 số.", 16),
    ("Tài khoản đã bị khóa. Vui lòng truy cập web để xác minh danh tính và mở lại thẻ.", 16),
    ("tk m bank của bé bị locked rồu, gửi cái ô tê bê t check liền cho ét ô ét", 16),
    ("cay đỏ zé luôn viet c0m bank báo trừ 20 củ, m gửi t cái otp xác minh lại vs", 16),
    ("ê t ngân hàng nè m ơi thẻ m bị rửa tiền r, c.k vô tài khoản này xác minh", 16),
    ("tải app v.c.b digibank fake này nhận ngay 5 chục m ơi ngon ơ", 16),
    ("acc bidv bay màu gòi, đọc otp cho m xem m cứu dc hong, chằm zn", 16),
    ("Bảo hiểm xã hội Việt Nam báo: Số sổ BHXH của bạn sắp hết hạn, nộp 500k phí duy trì.", 1),
    ("Chị bị sai thông tin bảo hiểm y tế, cung cấp mã OTP để cập nhật.", 1),
    ("Tiền tử tuất đã duyệt 20 triệu, đóng 2 triệu tiền phí hồ sơ để nhận tiền.", 1),
    ("Cơ quan BHXH thông báo bạn có trợ cấp thất nghiệp, click link để nhận.", 1),
    ("bhxh của t bị hết hạn r, m c.k t 5 trăm lo lót dùm t trc đi m", 1),
    ("số sỏ bhxh phông bạt thui t rút hết sạch r, click link tao gửi để bùng bhxh nè", 1),
    ("bạn t làm b.h.x.h bảo nay có trợ cấp, nạp 2 củ phí hồ sơ là giải ngân vô tk", 1),
    ("sổ b'h'x'h bị khoá r, ô tê bê gửi r đó điền dô đi pa", 1),
    ("dcm cái thẻ bhyt ko xài đc, tải app fake này nhập mặt là lụm bảo hiểm liền", 1),
    ("Quỹ nhân ái khẩn thiết kêu gọi ủng hộ lũ lụt. Hãy ck vào tk cá nhân này.", 10),
    ("Cháu bị ung thư đang cần tiền mổ gấp. Quý vị chuyển tiền ủng hộ.", 10),
    ("Chùa quyên góp xây tượng Phật, bá tánh chuyển tiền vào số MoMo này.", 10),
    ("Trại mồ côi gặp hỏa hoạn, thiếu quần áo thức ăn. Nạp thẻ cào giúp đỡ.", 10),
    ("lũ miền trung phông bạt vl, ae ck vô stk m đi t lo cho tụi nó 1 lèo xong lun", 10),
    ("nghệ sĩ hề mần từ bịp quá mệt, mấy pác c.k zô quỹ chó mèo của t đây nè", 10),
    ("bé mèo nhà e bị xe tông k tiền mua sữa, 500ae donate momo cho bé ik ét ô ét", 10),
    ("thương xót bé ung thư c.k mạnh vô stk 12344 trại nhi đồng lẹ lên m", 10),
    ("vợ ck a kêu gọi lũ lut tau làm từ thiên mượt hơn m cứ c.k t nha", 10),
    ("Bạn có kiện hàng nghi ngờ buôn lậu, nộp phạt 10 triệu để thông quan.", 17),
    ("Bưu điện báo phát đơn thất lạc, kiện hàng trị giá 500 đô. Thanh toán thuế tại link.", 17),
    ("Gói quà Mỹ kẹt Tân Sơn Nhất. Đóng 5 triệu tiền phí sân bãi để nhận.", 17),
    ("Xin chào tôi là bưu tá, anh có bưu phẩm chứa ma túy, để tôi nối máy công an.", 17),
    ("đơn hq bắt mnl rồi m ơiii, ck 5 cu đóng thuế rước vià xu cà na", 17),
    ("bưu đện kêu quà kẹt bãi, t kêu m nộp dùm tau 1 củ ship sao khum nạp", 17),
    ("HQ gọi t bảo buôn ma tuy m ơi cứu ét ô ét, nó đòi ck 10 chim bảo lãnh", 17),
    ("hải quan san bay bảo quà bị giữ r m c.k nộp phạt dùm t iu m mãi keo", 17),
    ("bưu điẹn bắt đóng thếu mới đưa đt, c.k tiền thuế dô link này dùm t vs", 17),
    ("Đang làm gì đấy tao bị tai nạn ô tô. video mạng hầm giật m chuyển tao 5 củ tk này.", 7),
    ("Con ơi bố ngã xe bác sĩ bảo đóng tạm ứng 15 triệu mới mổ, chuyển tiền gấp.", 7),
    ("Cô ơi cháu bé nhà mình bị té đập đầu cầu thang. Cô chuyển 20 triệu cấp cứu liền đi.", 7),
    ("Mày ơi tao dùng nick phụ gọi video. Quên ví, ck tao mượn 2 triệu tí trả nha", 7),
    ("đang cúp điện khum wifi t gọi deepfake đụng xe m ck t 1 tr cọc lẹ", 7),
    ("ê bồ t t.a.i n.a.n h mạng lag 4g gọi tậm tịt ck mượn 50 chiệu chữa SOS!!", 7),
    ("Cô là cô giáo bo nhe, bo ngã cổ rồi mẹ c.k viện phí nhanh khum trễ", 7),
    ("thằng a t bị chém toe máu me wé c.k t 5 cu vào viện gấp pa ét ô ét", 7),
    ("cam đt hư gọi vid mờ ảo m c.k dùm t 1 ít đi t mựơn gấp", 7),
    ("Shipper đây, anh không có nhà à, thế ck số tiền 200k vào Momo em ném vô nhà.", 17),
    ("Em giao Tiki, đơn này thanh toán rồi mà quên thu phí ship 30k. Nhấn link để trả.", 17),
    ("Đơn hàng trả về, chị vào link cài app theo dõi hỏa tốc để không bị mất hàng.", 17),
    ("Shipper giao sai địa chỉ, chị cấp quyền danh bạ cho hệ thống bên em quét giao lại.", 17),
    ("shipper fake gọi đòi 2 lóp bố m c.k vô momo thì scam, cay vãi chưởng", 17),
    ("em giao shopee nè chế, đang vắng thì xỉa momo em 1 củ e vứt qa rào", 17),
    ("m boom hàng xọp pi tớ block h c.k 50k hoàn ship zo stb này đi ml", 17),
    ("sh1pper gọi hoài ko bat máy t hủy cmn r m vao link này rui gop chieu nha", 17),
    ("mua tiktok xốp bắt c.k truoc hả, share qr tao phang momo 50 k r ném", 17),
    ("tải app check l.y.n.k shipper bom hàng đi má coi cho lẹ nèk", 17),
    ("Việc nhẹ lương cao bấm follow tiktok. Vốn nộp tk tổng là 15 tỷ crypto.", 12),
    ("Sàn ngoại hối Forex lãi suất 200%. Tuyển đại lý Nhóm nạp 5 triệu kéo lời.", 11),
    ("Tải app chạy bộ đa cấp, mua giày tiền ảo trị giá nghìn đô chuyển về ngân hàng.", 12),
    ("Hướng dẫn order đơn ảo trên shopee hoa hồng 20%. Đặt cọc 10 triệu nhận nhiệm vụ.", 12),
    ("cày view tóp tóp 1 ngày lụm 5 củ cho phẻ mắc mớ đi làm chi chằm zn", 12),
    ("m trade coin sàn phông bạt ez 100%, nạp margin 1 tỷ usd cho tới nóc ét ô ét", 11),
    ("tải cày pi ảo tưởng lm tỷ phứ r nè kkk c.k t ít làm vốn sàn forex đi m", 11),
    ("app cho nvu like face book thu loi nhuan gâp 5, ck tao 2 xị t tesst truc tuyen", 12),
    ("đầu tư f.o.r.e.x cmnr nạp vô sàn fx này quất 5 cu lãi ngay chục tr nè", 11),
    ("Chúc mừng thuê bao trúng tivi Sony. Click link điện lực nạp phí nhận.", 13),
    ("Bạn trúng xe SH từ Viettel. Nộp mã thẻ cào 5 triệu đồng để làm hồ sơ.", 13),
    ("Quay trúng iPhone 15 Pro Max Lazada. Bấm gọi hotline để đóng thuế phí lãnh giải.", 13),
    ("Zalo nhận lì xì 50 triệu từ quỹ nhà hảo tâm. Website yêu câu nạp 2 tr phí hồ sơ.", 13),
    ("ủa trúng air bờ rô mắc shopee gòi nè ck t 2 củ thuế t lụm zề xài kkk mãi keo", 13),
    ("nhắn sms brandname trúng sh mà bắt đóng v.a.t 5cu clm ảo ma canada ghê", 13),
    ("alo t trúng voucher qd c.a chốt don nap 1 ly tsua m c.k tao di", 13),
    ("1 phat trúng ip 15 ròi chời ơi khum tin duoc click l.j.n.k de nhan dclm", 13),
    ("nhan dc li xi zl nạp vip 5 xị rut ra duoc 5 chẹo lam theo tao nhe", 13),
    ("Alo dạo này công việc ở quê sao rồi, tụi trẻ con có ngoan không", 22),
    ("Chào buổi sáng! Em shipper khu vực tòa A nhận giúp em áo lạnh.", 22),
    ("Tối nay ăn lẩu nhé, lâu lắm hội đi Cát Bà chưa gặp từ dịch tới giờ.", 22),
    ("Chị ơi giáo viên trung tâm, nay bé nghỉ học vì mất điện chị ạ.", 22),
    ("Sếp ơi trưa bún chả không em gọi chung phòng mình luôn tính tiền sau.", 22),
    ("Mẹ ơi cuối tuần lên chơi với cháu, con ra bến Mỹ Đình đón.", 22),
    ("Tổng đài Mobifone xin nghe. Quý khách muốn bảo lưu gói 4G tháng?", 22),
    ("Báo cáo tháng 11 em gửi mail rồi sếp rảnh xem ký hộ em đóng mộc cái", 22),
    ("Bồ ơi quên cái áo khoác nè. rảnh tẹt qua tui đưa nha.", 22),
    ("Bác hội trưởng, tối nay họp dọn vệ sinh đường làng không bác?", 22),
    ("ê t mém tí tải app vNeid mạo danh h hú hồn m ơi ét ô ét", 22),
    ("Dạ sếp, file báo cáo BHXH sếp check chữ ký duyệt dùm phòng nha", 22),
    ("ê hqua xém bị deep fake lừa 50 củ cươi ẻ m ơi tối cf kể tao heheee", 22),
    ("Trại mồ côi kế quán nhậu á m c.k t lấy 2 thùng ken sương sương ha mãi keo", 22),
    ("t bị shopee boom hàng thối vlin tự ái c.k 10k t gánh game dcmm lẹ", 22),
    ("quẹt xe mấy chú 4ó p.h.a.t ng.u.o.i c.m.n 2 củ đói mõm, xu cà na", 22),
    ("má VNeID login khum được mi share man hinh teamview dùm nha tks mi", 22),
    ("ê t nghe can bắt ổ việc nhẹ lương cao nộp 15 tỏi vl r mai lẩu khum t bao", 22),
    ("đm tao chơi trade lổ lòi mồm rủ đi cf c.k momo t 3 chục t đổ xăng chạy xuống", 22),
    ("cái link lazada bị hưng gửi t nạp thẻ k dc bực m ck mượn momo t book grab m ơiii", 22),
    ("Đại úy Nguyễn Văn Hùng công an quận 7 đây, CMND anh dính án phong tỏa tài sản. Chuyển 30 triệu bảo lãnh.", 0),
    ("alo tui thiếu tá can huyện nè, bà bị tố cáo lừa đảo r đóng 10 củ nộp phạt qua momo lẹ", 0),
    ("viện kiểm sát gọi báo lệnh bắt giam, muốn tại ngoại ck 100 triệu vô stk viện phí", 0),
    ("bồ ơi can phường gọi bảo t có lệnh truy nã quốc tế, nó đòi t ck 25 chẹo bảo lãnh gấp SOS m ơi", 0),
    ("ê m tau bị c.a ép nộp tiền chuộc cmnd bị dính đường dây cá độ, c.k dùm 8 củ zo stk ni nha pa", 0),
    ("Thông báo: App VNeID phiên bản cũ sẽ bị vô hiệu hóa ngày mai. Tải bản cập nhật tại đường link này.", 1),
    ("cài vneid bản mới đê m, quét cccd qua cái link t gửi nè khum là bị khoá vĩnh viễn á", 1),
    ("Dịch vụ công quốc gia yêu cầu xác thực lại khuôn mặt qua Zalo video call để duy trì tài khoản.", 1),
    ("bạn t làm ở dvc bảo phải cài app .apk mới sync đc dữ liệu cccd gắn chip nè m ơi", 1),
    ("tui bên trung tâm hành chính ne, acc vneid chị bị treo r, share zalo video em reset giùm", 1),
    ("Techcombank cảnh báo giao dịch bất thường 50 triệu từ IP nước ngoài, xác nhận OTP để hủy chuyển khoản.", 16),
    ("ê mb bank bảo tk của m bị hack r, gửi mã 6 số cho t t khoá dùm cho m safe nha", 16),
    ("Agribank thông báo quý khách trúng gói tín dụng ưu đãi 500 triệu, bấm link đăng ký nhận ngay.", 16),
    ("tk tpbank m bị ai đó đăng nhập lúc 3h sáng, đọc otp gấp t lock acc cho m befor mất tiền", 16),
    ("sacombank gọi nè ông, thẻ visa bị charge 800 đô mua hàng amazon, đọc mã otp để t rollback", 16),
    ("BHXH tỉnh thông báo anh có khoản truy lĩnh lương hưu 15 triệu, đóng phí xử lý hồ sơ 1 triệu.", 1),
    ("thẻ bhyt m hết hạn r click link này gia hạn online khỏi ra phường nha m ơi", 1),
    ("Bảo hiểm y tế thông báo: Mã số BHXH của bạn bị trùng, cung cấp CCCD và OTP để sửa.", 1),
    ("t nghe bh xã hội gọi bảo có trợ cấp covid đợt cuối, nạp 3 trăm phí thủ tục nhận liền lun", 1),
    ("Hội Chữ thập đỏ kêu gọi quyên góp cho đồng bào bão lụt miền Bắc, chuyển khoản vào STK cá nhân này.", 10),
    ("ae fund rasing cứu bé 3 tuổi bị bỏng nặng nè, c.k momo tao tao chuyển thẳng viện cho bé", 10),
    ("Nhà chùa quyên góp phóng sinh cá chép, phật tử chuyển tiền vào số tài khoản sư thầy.", 10),
    ("group zalo kêu gọi cứu trợ động đất, ae c.k vô stk trưởng nhóm lẹ đi flood hàng tấn r", 10),
    ("Tổng cục hải quan thông báo lô hàng nhập khẩu bị giữ tại cảng. Nộp 8 triệu thuế để thông quan.", 17),
    ("bưu cục gọi nè, gói hàng từ Hàn Quốc bị scan ra chất cấm, nối máy cơ quan điều tra nha", 17),
    ("kiện hàng amazon m gửi về bị kẹt customs sân bay r, c.k 3 củ thuế nhập khẩu để lấy m ơi", 17),
    ("alo bưu điện đây, đơn EMS từ Nhật bị phát hiện hàng cấm, anh lên đồn ký biên bản hoặc ck 15tr bảo lãnh", 17),
    ("Ba bị giật điện thoại đang phải mượn máy người ta, con ck cho ba 2 triệu để ba đi khám vết thương trên tay nha.", 7),
    ("ê t nè gọi vid cho m coi mặt nè, t bị gãy chân rồi ck t 3 củ đi grab tới viện lẹ m ơi", 7),
    ("bạn thân m nè gọi vid đây nè tin t đi, t bị giật dtdd và ví r ck dùm t 1 ít mua vé xe về", 7),
    ("Cháu ơi bà ngoại đây, bà bị té cầu thang đập đầu chảy máu, chuyển 5 triệu viện phí nhanh giùm bà.", 7),
    ("m ơi mặt t đây gọi vid nãy r coi lại đi, t kẹt sân bay mất hết giấy tờ ck t 2 chẹo t bay về", 7),
    ("Em shipper grab nè, đơn anh bị hoàn do sai địa chỉ, click link tra cứu đơn hoàn tiền ạ.", 17),
    ("chế ơi em ship lazada, đơn chế trả tiền mặt mà chế k có nhà, c.k 350k vô momo em ném qua hàng rào nha", 17),
    ("Hệ thống Shopee Express thông báo: Đơn hàng bị trả về, vào app cài lại để theo dõi.", 17),
    ("ship tiki nè pa, đơn bị duplicate tính tiền 2 lần r, quét qr refund lẹ đi pa ơi nó auto hoàn", 17),
    ("Tuyển cộng tác viên đánh giá 5 sao Shopee, lương 500k/ngày. Nạp 2 triệu tiền cọc nhận nhiệm vụ.", 12),
    ("sàn binance copy trade ae vô nhóm tele lụm 20 tr 1 đêm, nạp 50 chiệu margin vô link này", 11),
    ("app đi bộ kiếm tiền nè m install lẹ, đầu tư 5 củ mua giày premium lụm passive income ngon ơ", 11),
    ("Join group telegram lụm xu mỗi ngày task nhẹ hều like sub share, nạp 1 xị unlock tier vip lãi x10", 11),
    ("ê m cày đơn ảo cho t trên sendo đi, hoa hồng 15% mỗi đơn nhưng đặt cọc 8 triệu trước nha", 12),
    ("Xin chúc mừng! Số điện thoại của bạn trúng giải nhất Galaxy S25 Ultra. Đóng thuế 3 triệu để nhận.", 13),
    ("m ơi m quay được cái airpods max gòi nè trên cái app qi kìa, đóng 1 củ thuế lụm zề xài", 13),
    ("Viettel trân trọng thông báo: Quý khách trúng 100 triệu đồng chương trình tri ân. Liên hệ hotline nhận giải.", 13),
    ("spin wheel trúng macbook pro trên lazada gòi ae ơiii, c.k 5 củ shipping rồi lụm miễn phí kkk", 13),
    ("Anh ơi tối nay đón con ở trường lúc 5h nhé, em họp muộn không kịp.", 22),
    ("ê hội cũ cuối tuần đá bóng sân Phú Thọ khum, t book sân 7 người r nha 200k mỗi đứa", 22),
    ("Dạ anh, em bên phòng kỹ thuật gọi báo wifi tầng 3 bị chập, chiều nay sửa ạ.", 22),
    ("Chị hai ơi ba má lên Sài Gòn thứ 7 nhe, chị ra ga Sài Gòn đón dùm em.", 22),
    ("m ơi đi lẩu Haidilao tối ni khum, t book bàn 8h r nha team mình 6 đứa", 22),
    ("Nhắc anh em nộp bảng chấm công tháng 3 trước 12h trưa mai nhé, HR cần tổng hợp.", 22),
    ("ê grab giờ tăng giá quá trời, t chạy xe máy qua đón m đi cf luôn ha gần mà", 22),
    ("Thầy ơi em gửi bài tập nhóm qua email rồi ạ, thầy check giùm em với.", 22),
    ("ba ơi con mua thuốc cho ba ở nhà thuốc Long Châu nhe, tối con ghé đưa", 22),
    ("t đặt momo chuyển m 50k tiền cf sáng nay r nha check dùm, tks m nhìu", 22),
    ("ê ku tao làm trên bộ CA nè m dính vô vụ đánh bạc nghìn tỷ trên r88 r ra phường gấp hoặc ck tao 50 củ tao lo cho m êm chuyện", 0),
    ("alo tôi là cán bộ sở TTTT, số đt của a đang mạo danh lừa đảo, trong 2 tiếng nữa sẽ khóa 2 chiều nếu k đóng phạt", 0),
    ("M dính líu đến ma túy đá xuyên biên giới rồi con ơi, ọc 30 củ ra đây can phường bỏ qua cho k xộ khám nhé", 0),
    ("tải app vneid pro max apk này đi m, khỏi cần quét mặt định danh vân tay chi cho mệt, link nà", 1),
    ("hệ thống dịch vụ công đang bảo trì, c.ck cấp quyền trợ năng t check lỗi hộ khẩu cho", 1),
    ("cán pộ thuế gọi báo t app DVC bị lỗi k đóng thuế đc, bắt t tải cái file .exe lạ hoắc ck 10tr tiền thuế má ơiii", 1),
    ("thẻ credit của ô đang bị trừ âm 10 củ, đọc mã otp cho e để e hold giao dịch trên hệ thống visa lẹ lên nha", 16),
    ("app bidv smartbanking báo nâng cấp db, nạp tối thiểu 2 tr vào ví điện tử liên kết để duy trì hạn mức", 16),
    ("ê tau NH nè tk m đang có giao dịch mua vé máy bay quốc tế 1000 đô, ko gọi video mbbank e ko support đc đâu", 16),
    ("bhxh của bác lương hưu k đc nhận do sai ngày tháng năm sinh, ck t 500k lệ phí điều chỉnh nha", 1),
    ("t rút BHXH 1 lần mà mụ ở ủy ban kêu nạp biên lai 2 củ tiền phí ms giải ngân m ơiii", 1),
    ("bảo hiểm y tế VssID hết hạn thẻ rùi, bấm dzô linc này đóng 8 lít per năm thui", 1),
    ("group face m có quyên tiền hỏa hoạn chung cư mini kh trc v? ck vô stk này của admin group đi e làm từ thiện lun", 10),
    ("xin 500ae donate cho viện dưỡng lão mồ côi ở gò vấp, số tk cá nhân 112233 thiện nguyện", 10),
    ("em cún bị lủng ruột nằm ngáp ngáp thuơng we 😭 😭 😭 ai giúp e ck momo sđt ni", 10),
    ("thùng Mac Studio từ bển gửi dzề bị bắt lại Tân Sơn Nhứt, nộp 7 củ thuế VAT liền t ra lấy cho pa", 17),
    ("giao hàng tiết kiệm báo kiện hàng a chứa đạn pháo k thông quan đc, vui lòng đóng phí bảo lãnh 10 củ", 17),
    ("hải 9 bắt đơn giày nai ky t gửi về nội bài r m, nộp 2 chẹo vô stk ông kẹ này lấy k nó tiêu hủy", 17),
    ("con đi học mất ví rùi ba hỏng cắm mic khum nói dc cK ba 5 chẹo ăn tháng này dô tk b t vs", 7),
    ("bé na bị tay chân miệng nhập viện gấp nè m ốm sập mặt gọi vid cam lag cm ra, mượn 2 cũ nhé", 7),
    ("tớ dính phốt trên trường đag trên phòng hiệu trưởng ck gấp 10 tr dô stk giáo viên cn t năn nỉ nha ko vid call dang hoi hop lam", 7),
    ("a bom shopee đồ sex toy t lêu lêu r h t bắt đền c.k 50k xăng xe ko t bốc phốt a", 17),
    ("J&T express báo đơn b hoàn thành mà thu tiền rồi báo lỗi k thấy t c.k lại b 30k vào momo rui bấm link confirm đi", 17),
    ("lazada cod 235k nhà a khóa cổng ae gõ rùi t vứt qua tường búng sđt 9982 ck nha", 17),
    ("cày like tiktok thả chym đc 50k/video nè, tải tele app rồi nạp quỹ 2M dô làm agent lụm tiền tỏi", 12),
    ("t bắt đáy con shitcoin doge lời x100, m nạp 10k$ dô sàn ftx2 chấm com cho t ké p&l", 11),
    ("làm full time mệt mỏi chi, tham gia group kéo baccarat vốn 1 củ bảo hiểm 100% ăn sure win 20 chẹo 1 ngày", 12),
    ("tin nhắn zalo trúng tủ lạnh LG xịn vãi nồi, t đóng 2 triệu tiền vận chuyển rồi sắp hốt zề nà", 13),
    ("đăng ký chương trình xàm xí fb trúng tour du lịch mộc châu c.k 1 củ cọc ăn uống thoai ez", 13),
    ("vinaphone tri ân kh quay trúng sh 150i nộp thuế trc bạ 15 củ dô stk chi nhánh lụm lẹ pa ơiii", 13),
    ("tối t gọi mess nhớ m ghé coopmart mua vài lốc sữa nha ba, momo t nộp tiền r", 22),
    ("sếp nói mai ai lên bp kế toán nộp form BHXH nhớ dán ảnh bìa đỏ nhé k là reject đó", 22),
    ("chuyển khoản momo t 15k ly cafe sáng tao mua cho mi nè, quỵt t đấm vỡ lù :)))", 22),
    ("kêu t test code bot ml tflite tao load cái lib tf error lòi loz, support dỏm ác v", 22),
    ("Alo tôi đại tá Trần Quốc Bảo Bộ Công An, số CMND anh đang bị đánh cắp để mở 5 tài khoản ngân hàng khác nhau rửa tiền quốc tế", 0),
    ("m ơi can quận gọi bảo t liên quan vụ án buôn người xuyên biên giới, đóng 80 củ bảo lãnh k là xộ khám 10 năm", 0),
    ("tòa án nhân dân tối cao ra lệnh phong tỏa toàn bộ tài sản, muốn giải tỏa ck 200 triệu vào tk kiểm sát", 0),
    ("anh ơi em công an xã nè, bà con bên đó báo anh trồng cần sa sau vườn, ra trình diện hoặc nộp phạt 50 triệu", 0),
    ("ê tau cán bộ tư pháp nè, hộ khẩu mi bị xóa do nợ thuế đất, c.k 15 củ trước 5h chiều nay k là mất nhà", 0),
    ("Cục An ninh mạng phát hiện IP nhà anh truy cập web đen, phạt hành chính 30 triệu hoặc khởi tố", 0),
    ("dạ chào chú, cháu bên viện kiểm sát gọi báo chú có lệnh triệu tập khẩn do CCCD bị lợi dụng mở thẻ tín dụng", 0),
    ("alo tui trung tá bên pccc nè, nhà ông bị nghi cháy do vi phạm pccc, nộp 5 củ phí kiểm định k bị niêm phong nhà", 0),
    ("SOS m ơi can tỉnh gọi bảo xe t gây tai nạn chết người mà t k biết, đòi 100 củ bồi thường k là bắt", 0),
    ("Trung tâm dữ liệu quốc gia thông báo: CCCD gắn chip của bạn sắp hết hạn, tải app cập nhật sinh trắc học ngay", 1),
    ("ê m tải app vneid phiên bản beta test nè, scan qr code này rồi share màn hình cho t hướng dẫn", 1),
    ("hệ thống DVC báo lỗi đồng bộ dữ liệu dân cư, cung cấp OTP để xác thực lại danh tính trên hệ thống", 1),
    ("dạ chị, em nhân viên bưu điện hỗ trợ đăng ký VNeID tại nhà, chị cho em remote vào điện thoại cài đặt giúp ạ", 1),
    ("CCCD chip mới bắt buộc cập nhật mống mắt trước 30/6, bấm link này đăng ký lịch hẹn tại nhà", 1),
    ("bạn t làm bên CA bảo app VNeID cũ bị lỗ hổng bảo mật, phải tải file APK bản vá từ link này", 1),
    ("Cổng DVC quốc gia yêu cầu xác minh lại tài khoản, video call Zalo với cán bộ để chụp khuôn mặt 3D", 1),
    ("tải cái apk vneid pro cracked này đi m, k cần xếp hàng quét mặt gì hết, t dùng ok lắm", 1),
    ("alo em hỗ trợ kỹ thuật VNeID ạ, tài khoản anh bị khóa 2 lớp, anh cài app teamviewer em truy cập sửa giúp", 1),
    ("ACB Smart thông báo: Phát hiện đăng nhập bất thường từ thiết bị Samsung Galaxy tại Campuchia, đổi mật khẩu ngay tại link", 16),
    ("tk vpbank m bị ai đó set up trả góp 500k/tháng mua iphone, đọc otp 6 số để t hủy giao dịch cho", 16),
    ("Em ngân hàng Vietinbank chi nhánh quận 1, thẻ anh bị clone skimming ATM, đọc số thẻ + CVV để em khóa khẩn cấp", 16),
    ("MBBank cảnh báo: Tài khoản bị trừ phí dịch vụ 2 triệu/tháng do không sử dụng, bấm link hủy dịch vụ", 16),
    ("ê t nv ngân hàng nè, hệ thống đang nâng cấp bảo mật, m gửi ảnh chụp 2 mặt thẻ ATM cho t đăng ký lại", 16),
    ("Sacombank Pay thông báo: Ví điện tử bị nghi sử dụng bất hợp pháp, nạp 5 triệu tiền xác minh để mở khóa", 16),
    ("anh ơi em tổng đài VCB digibank, có ai chuyển nhầm 30 triệu vào tk anh, anh ck lại dùm để em đối soát", 16),
    ("NHNN ra quy định mới bắt buộc liên kết tất cả ví điện tử với CCCD, quét mã QR này để xác thực ngay", 16),
    ("bidv smartbanking lỗi bảo mật nghiêm trọng, tất cả kh phải đổi pin + otp qua link này trước 24h", 16),
    ("BHXH Việt Nam triển khai trợ cấp thất nghiệp đặc biệt hậu COVID, nộp 1 triệu phí xử lý hồ sơ nhận 15 triệu", 1),
    ("sổ BHXH m bị trùng mã số với 1 người khác r, cung cấp CCCD + OTP qua link này để tách sổ", 1),
    ("dạ bác, cơ quan BHXH huyện gọi báo bác có khoản lương hưu truy lĩnh 3 năm, đóng 2 triệu lệ phí nhận 45 triệu", 1),
    ("app VssID bị lỗi đồng bộ dữ liệu với bệnh viện, tải bản cập nhật từ link này để dùng thẻ BHYT khám bệnh", 1),
    ("alo t vừa rút BHXH 1 lần online nè, m làm theo hướng dẫn trên link này nộp 500k phí là rút đc liền luôn", 1),
    ("Thông báo: Thẻ BHYT của bạn sẽ bị vô hiệu hóa do chưa đóng phí gia hạn quý 2, bấm link thanh toán ngay", 1),
    ("trung tâm BHXH quận thông báo anh được miễn giảm 50% phí BHXH, đăng ký qua Zalo OA này để nhận ưu đãi", 1),
    ("Hội cựu chiến binh kêu gọi đóng góp xây nhà tình nghĩa cho gia đình liệt sĩ, ck vào STK cá nhân trưởng hội", 10),
    ("ae ơi bé trai 5 tuổi bị ung thư máu cần 500 triệu, share mạnh tay c.k vào momo 0912xxx của mẹ bé nha", 10),
    ("Chùa Hoằng Pháp quyên góp xây cầu cho bà con vùng cao, phật tử ck vào tk sư thầy Thích xxx", 10),
    ("động đất miền trung tang thương quá ae ơi, admin group kêu gọi ck vào stk cá nhân admin gom tiền gửi xuống", 10),
    ("m ơi con mèo đường bị xe cán gãy 4 chân tội quá, t lập quỹ mổ cho nó ae c.k momo t đi ét ô ét", 10),
    ("trẻ em vùng cao đói rách tội lắm, t tự đi phát quà ae c.k vào stk t đi t quay clip chứng minh", 10),
    ("Quỹ Thiện Tâm kêu gọi ủng hộ bão số 9, vui lòng c.k vào số tk Vietcombank cá nhân 10201xxx", 10),
    ("Tổng cục Thuế phối hợp Hải quan thông báo kiện hàng từ Mỹ bị giữ do nghi hàng cấm, nộp 12 triệu phí giám định", 17),
    ("alo bưu điện VNPost nè, gói hàng COD của anh bị hư hỏng trong kho, ck 3 triệu bảo hiểm hàng hóa để bồi thường", 17),
    ("kiện hàng AliExpress m đặt bị chặn ở cửa khẩu Móng Cái, nộp thuế 5 củ + phí kiểm dịch 2 củ qua link", 17),
    ("gói quà sinh nhật từ Úc gửi về bị Hải quan mở ra phát hiện có thuốc tây, ck 20 triệu tiền phạt k bị khởi tố", 17),
    ("DHL Express thông báo: Kiện hàng trị giá $2000 của bạn cần đóng thuế VAT 10% tại link thanh toán này", 17),
    ("bưu tá giao hàng Lazada nè chế, đơn chế thanh toán online nhưng hệ thống lỗi bắt thu COD, chế ck trước 450k", 17),
    ("alo anh, kiện hàng quốc tế đang ở kho Tân Sơn Nhất, quá 48h không đóng phí lưu kho 8 triệu sẽ bị tiêu hủy", 17),
    ("Con gái ơi ba bị cướp giật rồi nè, ba đang nằm viện gọi video nè con thấy mặt ba không, ck ba 10 triệu mổ gấp.", 7),
    ("ê t nè gọi bằng máy bạn, dt t bị cướp v mất luôn ck chuyển dùm t 5 tri mua dt mới liên lạc", 7),
    ("anh trai m nè, a bị công an giữ xe do quên bằng lái, ck 3 triệu tiền nộp phạt để a lấy xe ra gấp", 7),
    ("bà ngoại đây cháu ơi, nhà bà bị ngập nước sáng nay, bà cần 10 triệu sửa nhà gấp ck vô tk bà nha cháu", 7),
    ("cô giáo chủ nhiệm đây e, bé nhà mình bị ngã ở trường đang cấp cứu, em ck trước 7 triệu viện phí ạ", 7),
    ("m ơi đt t hư cam vid bị đen, t ở bệnh viện Chợ Rẫy bị viêm ruột thừa mổ gấp ck t 15 tr phí mổ", 7),
    ("thằng A đây, tao bị tai nạn đang cấp cứu ở Việt Đức, vid call mạng lag cmnr ck tao 20 củ đặt cọc mổ gấp", 7),
    ("con gái ơi ba bị kẹt ở sân bay Nội Bài mất ví, ba mượn đt người ta gọi, ck ba 5 triệu mua vé về", 7),
    ("alo chị hai, em út đây, em bị tai nạn xe máy đang nằm viện Đà Nẵng, chị ck 12 triệu viện phí gấp chị ơi", 7),
    ("Anh ơi em ship Ahamove, đơn anh COD nhưng app lỗi không thu tiền được, anh ck 280k vào momo em nhé", 17),
    ("shopee express báo đơn anh bị trả về do sai số nhà, bấm link cập nhật địa chỉ để giao lại miễn phí", 17),
    ("chế ơi em ship ninjavan, đơn chế bị đánh dấu hàng giả, chế vào link xác nhận hàng thật k bị hoàn", 17),
    ("giao hàng nhé anh, đơn shopee COD 1.2 triệu, nhưng em k có tiền thối, anh ck chẵn rồi em thối lại qua momo", 17),
    ("em shipper be nè, đơn hàng GrabExpress của chị bị thất lạc, chị cài app track link này theo dõi", 17),
    ("lazada ship nè pa, đơn pa bị duplicate charge 2 lần r, quét QR code refund này hoàn tiền trong 5 phút", 17),
    ("anh boom hàng tiki t r h ck 200k cước vận chuyển 2 chiều ko t bốc phốt lên group review", 17),
    ("Tuyển CTV review sản phẩm Shopee tại nhà, lương 300-500k/ngày. Đặt cọc 1 triệu nhận đơn hàng đầu tiên.", 12),
    ("sàn forex uy tín top 1 châu Á, nạp 100 đô nhận bonus 500 đô, rút lãi về ví momo trong 24h", 11),
    ("app chạy bộ kiếm tiền health coin nè m, mua giày NFT 3 triệu chạy 1km lụm 500k passive income", 11),
    ("join nhóm tele signal crypto free, win rate 95%, nạp 10 triệu vào sàn này copy trade auto lãi x5", 11),
    ("tuyển admin fanpage lương 15 triệu/tháng, đóng 3 triệu tiền giữ chỗ + mua tool quản lý page", 12),
    ("m ơi t kiếm 50 triệu/tháng bằng dropshipping trên amazon, nạp 20 triệu mua khóa học + tool t dạy m", 12),
    ("đầu tư bất động sản metaverse nè, mua đất ảo 5 triệu bán lại 50 triệu sau 3 tháng guaranteed", 11),
    ("cày game P2E một ngày lụm 2 triệu, mua account seed 8 triệu t kéo ROI trong 4 ngày ez", 12),
    ("ê vô group zalo việc nhẹ lương cao đi, like video youtube mỗi cái 10k nhưng nạp 500k tiền cọc trước", 12),
    ("FPT Shop chúc mừng! Bạn trúng thưởng Macbook Air M3 chương trình tri ân khách hàng, đóng 5 triệu thuế TNCN", 13),
    ("m ơi t quay trúng ps5 trên app Lucky Wheel, đóng 3 củ phí vận chuyển quốc tế rồi lụm về xài", 13),
    ("SMS Viettel: Chúc mừng TB 0912xxx trúng 500 triệu CT Tri ân 30 năm. Liên hệ 1900xxxx nhận giải.", 13),
    ("ê vô shopee spin wheel trúng voucher 10 triệu r nè, nhập mã thẻ cào 2 triệu để active voucher", 13),
    ("Lazada LazMall tặng quà VIP: iPhone 16 Pro Max cho 100 khách hàng đầu tiên, đóng phí 4 triệu xử lý", 13),
    ("app zalo random drop 50 triệu tiền mặt cho 500 user lucky, nạp 1 triệu phí xác minh tk ngân hàng", 13),
    ("t trúng xe Vision 2025 chương trình Honda tri ân á m, đóng 8 triệu thuế trước bạ nhận xe liền tay", 13),
    ("Anh ơi chiều đón con học thêm Toán lúc 4h30 ở trung tâm Vincom nhé, em bận họp phụ huynh lớp út", 22),
    ("ê m cuối tuần đi Đà Lạt khum, t book homestay 4 người r đóng mỗi đứa 800k thui", 22),
    ("Nhắc họp team standup 9h sáng mai nhé mn, chuẩn bị update sprint review cho sếp nha", 22),
    ("dạ anh, em bên IT support công ty, laptop anh bị lỗi VPN em remote vào fix giúp chiều nay nhé ạ", 22),
    ("mẹ nấu canh khổ qua nhồi thịt rồi nè, tối về nhà ăn cơm đi con, đừng ăn ngoài hoài", 22),
    ("ê hôm qua xém bị scam cuộc gọi giả công an á m, nó đòi ck 50 củ may t cúp kịp", 22),
    ("bạn t làm ngân hàng VCB thiệt nè, hỏi dùm t mở tk tiết kiệm online lãi suất bao nhiêu", 22),
    ("dạ sếp, thu chi tháng 4 gửi sếp duyệt ạ. BHXH đã nộp đủ, lương đã chuyển cho team", 22),
    ("con ơi gửi mã OTP cho mẹ đi, mẹ đang đăng nhập VNeID trên điện thoại mới mua, mẹ k biết làm", 22),
    ("ship grab tới quán cf Highlands tầng 1 Bitexco ha m, t ngồi sẵn ở đây r nha", 22),
    ("t mới bị boom hàng shopee r m ơi tức cái máu, report seller vẫn k đc hoàn tiền", 22),
    ("má ơi con gửi tiền về cho má tháng này r nha, check vcb dùm con 5 triệu tiền sinh hoạt", 22),
    ("ê tao vừa đi phỏng vấn xong, mấy thằng bảo việc nhẹ lương cao t biết scam nên t bỏ r", 22),
    ("anh ơi bên Hải quan gọi báo đơn hàng amazon anh tới r đó, ra bưu điện quận lấy nha", 22),
    ("dạ cô, con nộp bài tập nhóm môn Machine Learning trễ 1 ngày được không ạ, nhóm con bị lỗi code", 22),
    ("m ơi t đặt grabfood ship bún bò tới office, chia tiền 50k momo nhé thanks m", 22),
    ("mẹ gọi nha con, bác sĩ báo kết quả xét nghiệm của ba bình thường, khum có gì lo", 22),
    ("ae dev ơi production server bị ssl cert hết hạn r, ai renew dùm gấp client báo 502 bad gateway", 22),
    ("t mới donate cho quỹ UNICEF chính thức 500k qua website unicef.org á m, cảm giác ý nghĩa ghê", 22),
    ("ê cuối tuần đi camping Hồ Cốc khum, team mình 8 đứa thuê lều 200k/đứa t book sẵn r nha", 22),
    ("Alo tôi cục cảnh sát giao thông, xe mang biển kiểm soát của anh vướng phạt nguội 15 triệu đồng, vui lòng cung cấp CCCD để xử lý.", 0),
    ("Cảnh sát cơ động phòng chống ma túy đây, số tài khoản của anh có dòng tiền bẩn chảy qua, yêu cầu tải app bảo mật để kiểm tra.", 0),
    ("tòa án nhân dân gửi trát hầu tòa cho chị về tội danh chiếm đoạt tài sản. Vui lòng chuyển 50 triệu ký quỹ để hoãn.", 0),
    ("bên an ninh mạng gọi báo anh đang phát tán virus độc hại, nộp phạt 5 củ qua số tài khoản này nếu không sẽ phong tỏa tài khoản.", 0),
    ("ông ơi công an gọi t m ơi, bảo t dính líu vụ án rửa tiền xuyên quốc gia, bắt nộp 100tr tiền bảo lãnh SOS", 0),
    ("Chị ơi tải file apk này cài đặt VNeID cho vân tay sinh trắc học mới nha, app trên CH Play lỗi rồi.", 1),
    ("alo tui hỗ trợ viên từ DVC Cổng quốc gia, gọi video zalo share màn hình để anh định danh mức 2 tại nhà.", 1),
    ("Cán bộ phường yêu cầu cập nhật lại cccd gắn chip qua đường link này vì dữ liệu hệ thống báo sai số.", 1),
    ("m ơi tải vneid fake này quét mặt cho lẹ đi, k cần qua phường cực lắm t làm thành công r", 1),
    ("Tài khoản BIDV của bạn vừa được cộng 50,000,000 VND từ một nguồn lạ. Vui lòng click link để hoàn trả nhằm tránh bị khóa", 16),
    ("Vietinbank cảnh báo: Có người đang vay tín chấp bằng CCCD của bạn. Nhập mã OTP để xác nhận và chặn khoản vay.", 16),
    ("ê techcombank t báo gd bất thường 200 củ, m có nhận mã otp 6 số ko đọc lại để t block account SOS", 16),
    ("Agribank E-Mobile: Bạn cần cập nhật sinh trắc học ngay theo quy định mới, nếu không tài khoản sẽ bị đóng băng. Bấm link", 16),
    ("nhân viên VIB nè anh, thẻ tín dụng của anh có dư nợ 15 triệu, thanh toán vào stk công ty đối tác 011122233 nha.", 16),
    ("Sở LĐTBXH thông báo bạn đăng ký thành công trợ cấp 10 triệu. Đóng 10% phí thủ tục vào stk để nhận chuyển khoản.", 1),
    ("sổ bhxh của thím bị khoá r, bà làm ở phường bảo nộp 1 triệu tiền cafe cho bà mở lẹ lên m ơi", 1),
    ("Ứng dụng VssID yêu cầu cung cấp OTP và mã thẻ BHYT để làm lại lịch sử khám bệnh. Vui lòng điền vào link sau.", 1),
    ("t bảo hiểm xã hội nè, m được duyệt hưu trí rồi nhưng báo sai quê quán, c.k 5 xị phí chỉnh sửa nha m", 1),
    ("Anh chị ủng hộ suất ăn đêm cho bệnh nhân nghèo BV Ung Bướu, 1 suất 50k ck vào momo quản lý quỹ nha.", 10),
    ("bé gái 2 tháng tuổi bị hở hàm ếch gia đình k có tiền, mọi người chung tay quyên góp STK cá nhân 048xxxx.", 10),
    ("đội cứu hộ chó mèo bị thiếu thốn vật tư dã man, c.k vào stk dưới để ae có tiền mua sữa cho mấy bé", 10),
    ("xả lũ miền bắc cuốn trôi nhà cửa, quỹ thiện nguyện facebook kêu gọi ae c.k vào sđt zalo này để tổng hợp", 10),
    ("DHL Express: Lô hàng từ Singapore bị giữ vì nghi ngờ có chất cấm. Vui lòng chuyển 10 triệu lộ phí kiểm định.", 17),
    ("Anh ra sân bay Tân Sơn Nhất nhận túi xách Gucci đi, nhưng trước đó phải nộp lại 3 triệu tiền phí bến bãi ạ.", 17),
    ("bưu tá j&t báo kiện hàng trả về cần thanh toán 500k phí phạt vì boom hàng nhiều lần, nếu không xóa nick", 17),
    ("Hải quan Nội Bài gọi bảo có người gửi anh cọc tiền 50k USD, anh nộp thuế 5% mới được nhận tiền về nha.", 17),
    ("Bác ơi con là Lan đây, xe con hư giữa đường tấp tiệm sửa xe, con mượn đt chủ quán gọi, chuyển con 1 tr sửa xe gấp.", 7),
    ("m ơi cam mạng lác quá t đi du lịch lỡ đánh rơi cái bóp r, c.k dô tk này giúp t 5 chẹo để t đặt phòng đứt", 7),
    ("Con ngoan ba đang ở viện, hồi sáng ba ngất nằm cấp cứu bác sĩ hối nộp tiền ứng 15tr, chuyển nhanh cho cô y tá", 7),
    ("anh a m nè gọi vid quay xíu thôi cho a mượn 8 củ mai a hoàn liền a đang ở tiệm cầm đồ căng lắm", 7),
    ("chị ơi em dâu nè, bé nó tự nhiên co giật e đưa viện gọi vid mạng giật e kbien thế nào c.k gấp e 10c e lo cho cháu", 7),
    ("chào a e shopee_express, a có đơn 300k mà a đi vắng e ném qa cửa nhe c.k vô stk Techcombank này dùm e.", 17),
    ("bạn có kiẹn hàng trả về người bán nhưng bị lỗi hoàn tiền, vui lòng click link điền tk nhận tiền", 17),
    ("hủy đơn nhìu quá tiktok shop khóa tài khoản b rồi c.k 50k tiền ship gửi trả kho r khôi phục tk nha", 17),
    ("chị nhận bánh kem nhưng bị rớt, e shipper k đền nổi c.k e 1 nửa cái bánh qa sdt này nha e tạ ơn", 17),
    ("alo e lazada, có đơn mỹ phẩm nhận hộ giùm người khác, 599k lấy k chốt c.k em lun nha e giục dô", 17),
    ("Kéo baccarat nhóm kín tỷ lệ ăn 99%, nạp vốn tối thiểu 2 củ vào stk quỹ để nhận mã bảo hiểm vốn.", 12),
    ("Làm CTV chốt đơn lazada tại nhà siêu dễ, chỉ cần nạp ứng trước 2 củ làm vốn xoay vòng ăn hồng 25%.", 12),
    ("ê t mới tìm đc sàn Wefinex 2 ae nạp usdt vào chơi nhị phân mau giàu vãi chưởng ck để mua khóa học t dạy", 11),
    ("Cài app like tiktok nhận hoa hồng nhé b, nạp lên VIP 2 mất 3 triệu ngày like 10 cái nhận 500k ez", 12),
    ("SMS từ SHB: Tài khoản của bạn trúng thưởng sổ tiết kiệm 1 tỷ đồng. Hãy click đường link điền thông tin và nộp phí 10tr rụt tiền", 13),
    ("m qua nhà t rữa giải trúng iphone 16 promax shopee đi m ơiiii, tới mới nộp 2 củ thuế cái là ship nó đem tới ah", 13),
    ("Chương trình Vòng quay may mắn MoMo: Bạn được tặng 1 voucher mua sắm 50 triệu. Chuyển khoản xác thực thẻ Visa 2tr để dùng.", 13),
    ("ê t trúng tour đà lạt 4n3d trên fb r, nó bắt nạp cọc 1tr giữ chỗ ck t 1 ít tao qua m bão nèk", 13),
    ("Bạn là khách hàng thứ 1.000.000 của OCB, được nhận set quà Apple. Nộp 5tr lệ phí phát hành giải thưởng vào stk hội đồng", 13),
    ("sếp dặn em in báo cáo KPI tháng này r để trên bàn sếp chưa ạ, chiều sếp về cần coi gấp", 22),
    ("mê trà sữa ô long quá m ơi c.k momo t 35k t đặt chung quán đang flashsale", 22),
    ("bạn ơi tiền vé xem phim hôm trc tớ ứng trc r á, ck bạn gửi lại t nha stk cũ", 22),
    ("a gửi t số cmnd + hình 2 mặt để book vé cho đúng tên nha k mai ra sân bay ngta k cho checkin rắc rối", 22),
    ("xe hư òi đết qua đón được nha m, tự bốc xe ôm tới nhà hàng r ae mình vào ăn chứ trễ quá rùi", 22),
    ("tôi cảnh sát cơ động, yêu cầu dừng xe kiểm tra nồng độ cồn, không hợp tác phạt 40 triệu", 0),
    ("bạn có lệnh bắt tạm giam từ VKS nhân dân tối cao do lừa đảo đất đai, nộp 200tr bảo lãnh", 0),
    ("đội điều tra tội phạm ma tuý đây, STK ngân hàng của anh dùng nhận tiền ma tuý, xoá tội giá 50 củ", 0),
    ("tòa sơ thẩm hn ra phán quyết niêm phong nhà bạn, gọi tổng đài để nộp 100 triệu kháng cáo", 0),
    ("tôi trung tá phường x, con ông dính lô đề cờ bạc bị bắt, mang 10tr lên phường nộp phạt kín", 0),
    ("alo sở kế hoạch đầu tư đây, cty a bị tố trốn thuế, nộp 30 triệu phạt hành chính qua ck", 0),
    ("bộ công an báo: cccd của bạn mở cty ma rửa tiền, ấn phím 9 để nộp phạt 50tr hủy hồ sơ", 0),
    ("tui làm bên quân đội, khu nhà bạn sắp giải tỏa, ck 10tr tui sửa quy hoạch cho", 0),
    ("anh nợ tiền phạt giao thông 2 năm r, nộp ngay 12 củ tiền phạt kèm lãi qua số tài khoản kho bạc", 0),
    ("thanh tra giao thông đây, xe a bị chụp lỗi vượt đèn đỏ, chuyển 2 triệu vô tk xử lý nhanh", 0),
    ("Cảnh sát KT báo: Anh đang thuộc diện tình nghi buôn điện thoại lậu, chuẩn bị 500 triệu ký quỹ", 0),
    ("em làm phường này anh, a vi phạm trật tự xây dựng, đưa e 20 triệu e lấp hồ sơ cho êm", 0),
    ("văn phòng luật sư báo cáo bạn bị khởi kiện mượn tiền k trả, chuyển 40tr phí hòa giải", 0),
    ("ALO 113 đây, xe bạn tình nghi gây tai nạn lẩn trốn, ck 15tr vào quỹ ủng hộ để thoát án", 0),
    ("an ninh mạng đây m, facebook m múa phím chửi lãnh đạo bị lưu log r, nộp 5 củ xoá log lẹ", 0),
    ("anh lên google tải DVC.apk về cài chứ máy k hỗ trợ update định danh mức 2 qua mạng nha", 1),
    ("tài khoản VNeID bị hack, anh nhắn mã OTP để em đổi lại sđt khôi phục cho hệ thống", 1),
    ("cài vneid lởm này chi m, quét app này 1 cái dô lun khỏi vân tay bảo mật j hết", 1),
    ("bưu điện nhận làm căn cước công dân gắn chip tại nhà, cô nộp 300k làm lệ phí", 1),
    ("app Cổng DVC gặp sự cố, quét qr code em gửi rồi đồng ý toàn bộ quyền truy cập để fix lỗi", 1),
    ("thuế điện tử etax mobile đổi sang app mới, tải file apk trực tiếp ở link này cài nhé chị", 1),
    ("định danh mức 2 lỗi mống mắt, kết bạn zalo em gọi video call để thu thập lại khuôn mặt", 1),
    ("Tài khoản dịch vụ công quốc gia của bạn chưa đóng phí dữ liệu năm 2024, truy cập link nộp 100k duy trì hệ thống.", 1),
    ("khỏi lên phường m ơi, đưa t 5 trăm t làm cho nhanh vn.e.ID mức 2 trong 5 phút full VIP", 1),
    ("tài khoản dvc chưa xác minh, yêu cầu anh đóng phí 100k vào kho bạc online để active", 1),
    ("dịch vụ công báo hồ sơ đất bị kẹt, tải web này c.k 2 triệu lót tay r rút hồ sơ nhanh", 1),
    ("định danh lỗi r anh trai, cung cấp số cmnd cũ và mới, thêm cái sms otp để t chỉnh db", 1),
    ("zalo con AI này nó nhận diện khuôn mặt thay cho vneid dc lun đó, click tải đi test thử m", 1),
    ("Cục cảnh sát qlhc thông báo, để duy trì tài khoản DVC, nạp 50k vào ví điện tử nhà nước", 1),
    ("alo hệ thống vn e id lỗi toàn quốc, ai muốn xài bthg nộp 200 cành qua app test này", 1),
    ("MB Bank thông báo: Giao dịch 25,000,000 VND bị treo do sai mã bảo mật, click hoàn tiền", 16),
    ("tk vietcombank của bà dính lỗi trừ âm 3 củ gòi, đọc t cái otp t rollback lại gấp", 16),
    ("techcombank ưu đãi mở thẻ tín dụng miễn phí 100tr, đóng phí hồ sơ 1 triệu vô tk tư vấn", 16),
    ("ví momo nạp quá hạn mức 50tr/ngày, muốn mở rào nạp thêm 500k làm xác minh 2 bước", 16),
    ("sao kê tài khoản vpb của a đang bị leak, bấm link đăng nhập lại để thay đổi mk ngay", 16),
    ("vay tín chấp ngân hàng ls 0% giải ngân 300 củ, chỉ cần ck 3 củ lệ phí chứng minh thu nhập", 16),
    ("tổng đài SCB báo: Khoản vay của a tới hạn 10tr, ck vào tk nhân viên để e quyết toán nội bộ", 16),
    ("zalopay thông báo tk đóng băng vì thiếu cccd, nạp 5 triệu vnđ vào số 098x để unlock ví", 16),
    ("thẻ credit mbbank tự động cà 5 củ bên mẽo, đọc e mã otp sms để báo cáo hủy gd quốc tế nha", 16),
    ("SHB Finance cho vay online 50 tr k thế chấp, vui lòng nộp phí đăng ký khoản vay 2.5 triệu", 16),
    ("ACB cảnh báo đăng nhập nghi ngờ lúc 2am, bấm hủy giao dịch ngay tại link acb-smart-vn.com", 16),
    ("sdt này vừa mở thẻ visa techcombank nợ 15 củ, ra ngã tư đưa tiền mặt cho nv thanh lý nợ", 16),
    ("nhân hàng o cê pb bank gọi báo tk trúng sổ xố nội bộ, ck 2 củ phí giao dịch nhận 100 củ", 16),
    ("vnpay lỗi app, tk của a vừa bị khóa do nạp sai tiền, gọi tổng đài nạp thẻ đt 200k mở khóa", 16),
    ("app bidv bị xóa khỏi store rùi m ơi, tải app bidv_dev này chạy mượt hơn mà lại hay đc bonus", 16),
    ("Bảo hiểm thai sản báo bạn bị thiếu giấy tờ, click link bổ sung hoặc đóng 1 củ phí xác nhận", 1),
    ("cò làm bhxh đây, muốn rút 1 lần ngay trong vòng 2 nốt nhạc c.k t 5 triệu đi t lo lót nhanh", 1),
    ("VssID lỗi đăng nhập, cung cấp OTP t gửi qua đt để khôi phục mật khẩu bảo hiểm ý tế", 1),
    ("Sở Y Tế yêu cầu đóng phí bảo hiểm thu bổ sung Covid 19, mức phí 500k nộp qua mã qr", 1),
    ("bảo hiểm hưu trí tháng này phát chậm do lỗi bank, gửi số cccd và thẻ atm t update lại stk", 1),
    ("Rút BHXH sớm 5 năm bị lỗ, t quen sếp trong đó, m c.k trước 3 củ đi t đẩy hồ sơ cho max tiền", 1),
    ("bhyt của bạn chưa đồng bộ VNeID, nạp phí đồng bộ hệ thống 50k qua momo để đi khám bệnh", 1),
    ("Trọng tài lao động: Cty nợ BHXH 3 năm, bạn tham gia group vip đóng v.a.t 2 củ để kiện lấy tiền", 1),
    ("alo e bên y tế dự phòng, bảo hiểm anh chị bị thu hồi do sai cmnd, đóng 500k làm mới thẻ k mốc", 1),
    ("vssid bảo cấp sai thẻ bhyt r kìa pa, gửi cái otp tui xin cấp lại thẻ mới lẹ lẹ đê", 1),
    ("Trẻ em Lào Cai rét đậm k áo ấm áo, cô dì dượng ủng hộ quỹ cá nhân e số tk này nha 10k cũng quý", 10),
    ("trung tâm trẻ tự kỷ Củ Chi sập mái nhà cần góp tôn lợp lại, ck sđt thầy Hải mua vật liệu gấp", 10),
    ("các ac ơi quyên tiền mổ sỏi mật cho mẹ đơn thân ở Q12, stk momo nhà hảo tâm này e đi thu dùm", 10),
    ("cứu trợ lũ bùn sạt lở, bà con đói khát, mn ck vô quỹ tự phát của hội FB này e trực tiếp đi phát", 10),
    ("sư cô đang xây tượng 20 mét thiều xoài tiền, phật tử chung tay c.k vô tk chùa_fake_xxx", 10),
    ("bé 3 tháng tuôi k mang dc mổ tim SOS ae vo zalo e chk de e dong tien vs nha thương xót e vs", 10),
    ("giải cứu chuối giúp bà con nông dân bị ép giá, các bác ck đẹt hàng trước 50k 1 buồng e giao tân nơi", 10),
    ("hội bảo vệ động vật đang có 50 bé chó xắp bị lò mổ, ae gom tiền đủ 10 củ chuộc hết 50 bé STK dưới", 10),
    ("cơm 0 đồng bị đập quán, khách quyên tiền qua tk để e sắm nồi niêu nấu lại nha các bác", 10),
    ("ông lão bán vé số mù bị cướp đâm nhập viện, mn chuyển tiền ủng hộ ông thay vì mua vé nha", 10),
    ("Hải Quan TPHCM: Túi Dior anh nhập qua amazon bị nghi là phế liệu, nộp 10 triệu xử lý tiêu hủy", 17),
    ("đơn hỏa tốc từ Hàn về dính thuế thu nhập 2 củ, a ck vô stk giám đốc hải quan 01222 cho lẹ ngta giao", 17),
    ("alo bưu cục VNPost Tỉnh nè, kiện hàng dính nước hẩm hiu đền 50củ nhg yêu cầu nạp 2 củ tiền phí check", 17),
    ("GHTK thông báo: Gói hàng của bạn chứa ma túy tổng hợp, vui lòng hợp tác điều tra qua video call", 17),
    ("chị ơi quà Noel bên Canada gởi về bị hải quan Mộc bài giữ lại, nộp 6 triệu xèng bến bãi cho qua cửa", 17),
    ("shopee quốc tế bị chặn cửa khẩu kìa e, thanh toán 500k phụ phí xăng xê bưu cục mới mở kho", 17),
    ("Bưu điện TW: Thư chuyển phát nhanh của anh là bằng chứng giả, nộp 15 triệu nếu không chuyển qua tòa", 17),
    ("amazon prime lỗi free ship, bù ship hỏa tốc 45$ qa thẻ visa này t đẩy đơn qa cửa khẩu tq cho m", 17),
    ("hải quan cảng tân thuận gọi m báo cont hàng trái cây bị thúi, đóng 80 củ phí huỷ nếu k phạt x10", 17),
    ("bạn có 1 gói quà iphone bị giam tại kho J&T, nt mã số tk t t nộp 2 củ thuế thuế thay r t thối lại m", 17),
    ("Cô ơi, bé Bin đang đá banh bị gãy chân vô viện, vid mờ xíu nhưng ck 10tr viện phí nộp mổ cô", 7),
    ("a hai bị pikachu hốt xe máy k có bằng, mạng 4g giật ghê t ck a 3 củ a đưa cho CA lẹ nhe", 7),
    ("alo e, ba mẹ đi chợ bị rớt bóp. Gọi mess lác xíu, ck qua STK chủ sạp 2 củ cọc tiền đồ đi e", 7),
    ("sếp gọi vid nãy h k dc do xài đt cùi ck mượn 20m chuyển đối tác ăn tiệc cái tý về lấy lại nha", 7),
    ("m ơi vợ t trở dạ bệnh viện từ dũ bắt đóng 15 triệu tạm ứng, gọi vid đứng lag t bấn wa e ck t mượn nha", 7),
    ("bé nhà m bị điện giật trường cúp điện k wifi gọi k thấy m ck gấp quỹ y tế cấp cứu trường 100tr!", 7),
    ("ê t dính tai nạn h k di chuyển nchuyen dc tk kia bắt đền 10 củ c.k tao m nhe cam bể nát k thay man hinh r", 7),
    ("đm bị giật túi sách trắng trợn đêg đi sg, m ck tao momo sđt ng di duong t lay tien ve vũng tàu đi t thề trả", 7),
    ("alo ba, má ở quê ngậm xương gà mổ cổ họng, c.K con 5 chẹo ở viện Chợ rẫy bác sĩ hối nộp phiếu", 7),
    ("a đâm trúng xe mer đi ké ngta cam tối om, thg kia đòi 20tr bồi thường nguội ck a lk nha kien tụng oải lắm", 7),
    ("o dượng, t rớt visa du học kẹt tiền bay về mb, đt rớt mẻ r nên gọi vid k nghe, ck 5tr tiền grab t về vn", 7),
    ("con ơi bố t bị suy tim nhập viện khẩn k nói dc video đang quay máy mờ cmg c.k 50tr mổ r lấy sau", 7),
    ("e ơi nhà cháy r, alo k nghe rõ mạng rớt, e h c.k stk ck a 20tr a thanh toán tiền hotel ở đở đêm nay", 7),
    ("má ck gáp momo 1 trieu tiệc cty a quên ví, dth hỏng cam trước đang bị đen ngòm k xài vid call dc nhe", 7),
    ("anh a m nè mạng sập call wifi k nnet, t bị CA p.hạ.t h tạch 5 củ c.k mượn chốc a trả lại gấp SOS", 7),
    ("Ninja Van đây anh boom đơn COD 310k phạt kho bắt đền 5 củ đó c.k 300k r em giữ xe về tự lấy", 17),
    ("chế ơi t shopee food giao 10 ly trà sữa bị rớt gãy tay k lên đc, c.k em 500k an ủi tiền sửa xe nha c", 17),
    ("viettel post giao hỏa tốc 200k nhưng em lỡ làm móp hộp, anh ck đỡ 50k xăng cộ em bỏ wa lun nhé", 17),
    ("bạn k nhận hàng shop lazada đánh gậy sao, bấm qr momo thanh toán 15k cước ship r shop thả gậy", 17),
    ("grap giao hàng tiết kiệm nè anh ôi, đơn amazon trả tiền mặt đíu cho cà thẻ, c.k t 1tr5 t nộp kho lẹ", 17),
    ("m boom xop pi tao r tao cay tao bốc phốt group địa phương, ck 100k thẻ game xin lỗi tao đi", 17),
    ("đơn hhtk cod 102k t quăng đại gốc cây, bị chó tha r a tự chịu hay ck 50k t đền hàng cho a chớ t k bik", 17),
    ("lazada hoàn tiền đơn bể tủy, nhập mật khẩu icloud vô link e xác thực mới rớt tiền zề nha chị ới", 17),
    ("Grab express a ơi sai định vị tòa nhà 10km, a nổ lại 150k tk grab này k t hủy bỏ đơn luôn đó", 17),
    ("Đơn bị lỗi trọng lượng shopee charge thêm 1 lốp, quét code này hối 100k nha chị r em quăng dzô nà", 17),
    ("chị chê be giao dỏm t hủy r, c.k t 20k phí dịch vụ hệ thống chứ k be nó sút t đi lun c ới", 17),
    ("shịp 5h sáng tiki a kh ngủ ngta quăng cme lun cho r, ck e 5 xị tiền boa e chờ tới 8h gd choa", 17),
    ("GHTK thông báo: Số điện thoại nằm trong blacklist boom hàng, click nạp thẻ đt 50k gỡ blacklist", 17),
    ("beBike nè e ơi giao bó hoa 500k mà a lỡ mần dập 1 xíu, a ck trả e lại 20k cho huề e đừng report nha", 17),
    ("shiper xọc pi tao tới rưng k có sdt m goi dc, m gọi tao xíu ck tk tao 3 chục t ném luôn hàng dzô", 17),
    ("nhóm zl đọc phím ăn non Baccarat ăn 5 cụ/ngày. Đóng tiền nhóm 1 triệu VIP để ăn theo 100%", 12),
    ("Làm nv seeding tiktok tháng lụm 20 củ dễ ẹc, muốn vào room vip thì nạp tiền cọc 3 triệu để mở khóa nha m.", 12),
    ("sàn wechain_io sập ăn m, nạp 1k usdt vô ví t để kéo margin 20x x10 x100 tài khoản trong phút 1", 11),
    ("làm affiliate tiktok shop không cọc không vốn á? sạo l, tải app telegram tao chỉ, nộp 300k học phí lun", 12),
    ("bỏ làm thuê đi, mua token X_bull x50 rùi c.k tao 10 củ tao share l.l.code mua sớm trên binance dẽ", 11),
    ("tển nv thả tym shopee 50k 1 tym m c.k t giữ chân 2 củ đi tao add mày vô hệ thống chóp bu nhen", 12),
    ("dạy trade phái sinh vàng forex bao thắng, rủ rê đc 1 ng add momo tao t cho 10% hh, nạp min 100 củ", 11),
    ("chơi game xếp hình nft lụm trăm đô/ngày m, phải up VIP1 nộp 3 tr VND vào ví trung gian trước nghen", 12),
    ("đánh order grabfood ảo kiếm hoa hồng hoàn, m cọc 1tr nhập sdt này t tao giao m bill ảo để hốc xiền", 12),
    ("đầu tư x2 mỗi tuần lãi, mô hình ponsi siêu an toàn t x3 r, ck momo t 5 chẹo t add dzô gr vip gắp lun", 11),
    ("ê app nhận lãi 5% / ngày dập fb kìa pạn nạp 2 củ vô web này 3 ngày sao ăn đày đủ 3 củ rỉa lun đi", 11),
    ("tển cộng tác viên bình luận ảo fb pr dịch vụ nha khoa, phí đg ký 500k/tháng lụm 50k/ cmt siêu dễ", 12),
    ("bắt đáy coin shit lẹ lên x2 chục lần c.k tiền việt vô stk t t xài visa quẹt nạp binance mua cho b", 11),
    ("đầu tư bất động sản chung rủ 10 củ 1 slot sổ hồng chung chia tỉ lệ, ck a giám đốc cty đia ôc lẹ", 11),
    ("xài mã bot telegram auto spin trade fx x3 tk, 20 củ mua bot t setup cho auto thụ động tới zà", 12),
    ("Bạn Trúng IP 15 Titan từ Momo do quay số tết. Nhấp VÀO ĐÂY, chuyển lệ phí vận chuyển 5 củ trước", 13),
    ("Vietel Store chúc TV Trúng sh Mode. Vui lòng ck 20 củ phí thuế TNCN và cà-vẹt trong zòng 2h sau", 13),
    ("m trúng cmn tvi samsung ở siêu thị lotte r khứa ơi, đk gửi đi t ck bảo vệ 2 lít tiền tip ngta đem ra hs", 13),
    ("zalo random gift xả 1 tỷ đồng 1 người may mắn đc 50 triệu m, nộp card 500k vinaphone mở khóa", 13),
    ("ngân hàng SCb báo trúng vàng sjc cành mai, c.k 5 chẹo vô tk chi nhánh để lấy biên nhận nhe", 13),
    ("ủa sao m trúng Macbook pro trên đg link fb đó v, tao tải về bắt nạp momo 1 củ xác thực mạo danh m ơi", 13),
    ("Garena thông báo tk game trúng gói vật phẩm kim cương. nt thẻ đt 100k vina wa zalo m lấy code lẹ", 13),
    ("shopee báo trúng 500k tk xu. Nhập mã otp dt zo tk m r nạp card 100k cho cty viễn thôg nhe", 13),
    ("sự kiện lotte cnl trúng lốc tủ đông r m, tới thu 5 củ tiền thuế nhập k.h.a.u để khiêng tủ dzia thoai", 13),
    ("Trúng giải tri ân khách Vip Honda oto VN nè trúng civi lun má ck e 15 củ phí bảo hiểm em ship 3 miền", 13),
    ("app qqu trúng voucher 10tr du lịch sing m ck 500k phí tư vấn visa r t làm lun r đi cho phê", 13),
    ("ê vnpt báo tb m trúng sổ tiết kiệm 100 chẹo kìa, để nhận thì nạp zô tk 500k gọi là kích hoạt sim đg trúng", 13),
    ("App này nó báo trúng tivi 50 inch xong bắt tao đóng phí hồ sơ 3 củ để nhận, lừa đảo chắc lun đkm.", 13),
    ("bốc thăm fb cty dkm trúng 1000$ usd tiền tươi luôn c.k 100$ vô tài khoản paypal chuyển đổi rate usdt", 13),
    ("Chúc mừng quý khách quay trúng xe SH từ Tiki, vui lòng thanh toán phí phí trước bạ 10 triệu để lên hồ sơ xuất xưởng.", 13),
    ("chiều rảnh khum a mình đi aeon mall tân phú chơi bowling t đặt vé 150k ck tao đi cho đủ point voucher", 22),
    ("ê m check mess t gửi ck 30k dằn dơ tiền khô bò tao mua đi nhen nợ dai như bò, ầu ơ ví dầu", 22),
    ("t bị trừ 25k ví zalopay tự động nạp youtube premium cmnr bực mình vl, h quên hủy gia hạn v l", 22),
    ("a trưởng phòng phòng bhxh nói nộp lại cmnd bản gốc r, lên văn phòng cty nộp cho hr nhanh nhó", 22),
    ("Alo grab đây em đậu trước vinmart gòi, a xuống lẹ đi em đi đơn ghép k chờ lâu được kẹt xe qa", 22),
    ("m ơi tải app VssID xịn vô update lại cmnd nhe k là mốt đéo xin đc trọc cấp thất nghiệp á kkk", 22),
    ("tối h chơi chứng khoán VND đỏ vl rủ mi uống cf 40k bao t nhe, bữa nay chạy xọc pi ế chảy mỡ ra cmr", 22),
    ("mẹ mua cua hoàng đế rồi con tranh thủ học r phi thẳng dzia nhà nấu lẩu cua ăn 2 má con he", 22),
    ("GHTK báo em không nghe máy r em boom mịa luôn 150k váy rẻ rách sọt rác, kệ mịe shiper nói l. l.", 22),
    ("cài vn e id bị lỗi khum scan dc cccd, lên c.a phường đăng ký lại đi chứ ở nhà tự làm k có dc pa ớiii", 22),
    ("gọi fb m mém bị giựt đthoại tao sợ vãi lol, tối h t éo dám cầm đt ra đường r c.a tp dạo này yếu qá", 22),
    ("Sếp ký vội tờ hóa đơn thuế gtgt r t đem đi cục thu.ế đnăng nộp liền c.k t tiền grab đi giao r e gửi cọc", 22),
    ("t thấy gr kêu gọi từ thiện chùa bà đanh 50k/người legit k m, thấy ngta đưg ảnh xậy cầu có vẻ tín, c.k m thử?", 22),
    ("hqua t lướt tóp tóp thấy bọn tuyển ctv order kiếm tiền lừa đảo quá t rủ m vào nhóm report tụi nó chơi kh", 22),
    ("anh ơi đơn ahamove của văn phòng giao 5 trà đào tớ cty r anh xuống lấy or e để quầy tân nhe phí 215k dặ em done gòi", 22),
    ("c.k tao 5 lít đi mai đi mua đồ ăn lẹ nha con phò", 22),
    ("tội thằng bé hqua mới cọc 20 triệu mua oto bị hủy cmn đơn mẹ cay vđ, t đang chửi nó ngu nè", 22),
    ("alo viettelpost nè, a xuống lấy thùng cherry 5 lít hqua gởi gòi nhe, tớ cty nha", 22),
    ("tối đi coi bói hông con dở, xem tình duyên chuẩn vl kkk đm c.k tao 5 xị book thầy đi", 22),
    ("công an phường đang đi thu thẻ cccd dở dang ở hẻm mình á, m nộp sổ hộ khẩu vs cccd chưa", 22),
    ("Trang web tổng cục thuế mới sập cmnr a vừa tính nộp tiền khai thuế gtgt luôn wtf", 22),
    ("Bên cục thuế HCM ới gọi t lên cung cấp ds nhân sự nè m in ra tờ A4 liền tớ nha lẹ đi m", 22),
    ("chiều h hỏng mẹ cái app vneid, đéo xài trích xuất cccd đc bực mình thật sự", 22),
    ("này đt con ghệ nhắn đúm hk, nợ 1 chẹo tiền mì tôm tao tối nai ko trả tao phốt chết m", 22),
    ("khóa sim đí mẹ t xài dcom đéo có sóng 4g chán điên, gọi cskh vina hộ t xíu nha bb", 22),
    ("hqua xe tao bị công an hốt dm tốn 2 chẹo tiền phạt ngu vc may hong giam bằng lái kkk", 22),
    ("lên voz chúng nó đang kể đúm phốt mấy thằng đa cấp dụ mua coin lol lừa đảo vkl kkk", 22),
    ("m thấy vụ 20 tỷ trúng vietlott chưa tao đéo tin tưởng trò này xạo vđ toàn ng nhà trúng", 22),
    ("shiper đang đứng vỉa hè nắng chets mẹ m ck tao 4 chục t lấy cơm lun ko ngta chửi t sml", 22),
    ("ủa tin nhắn otp báo hủy dv sms banking của agri sập hay clg, m xem tao h bị hủy á bực vãi", 22),
    ("tao xài fb dính phốt chặn cmt bực vc, fb mạo danh nó block tao luôn chửi chó đẻ mark", 22),
    ("Hqua mới gởi ba 3 tr góp qũy chùa thầy lộc ổng cảm tạ cúng sao giải hạn đồ, vui vđ", 22),
    ("cty bhxh nhắn tin kêu bh thất nghiệp giải quyết xog tớ ngân hàng chi nhánh tân bình lấy rui đó m", 22),
    ("alo e grab đây tới chành xe r a đem 3 kiện ra giúp e nhe, cod 300 ngàn phí nhe", 22),
    ("dạo này chứng khoán đỏ lửa tao bán sạch danh mục thu hồi tiền gởi bank mẹ rkkk", 22),
    ("mua xổ số ích nước lợi nhà đi pạn c.k tao 20k mua tờ zé trúng giải cặc kkk", 22),
    ("thằng trưởng line ql 5 nợ 5xị tiền trà dá clm nhây thật t lầy vl thag chó đòi mãi đéo trã", 22),
    ("Bv chợ rẫy đông chết mẹ chen chúc chờ khám tốn 5 lít tiền dịch v khám xong đuôi luônn", 22),
    ("má dạo này nhiều con làm app sếp bị lừa 5 tỏi clm sợ thật ae rãnh lên cảnh báo ba mẹ đi", 22),
    ("app VssId bữa nay mượt vãi update ver mới scan mặt nhanh gắp ck tao 5 chục đi", 22),
    ("tới shopee lấy con đt dùm, lụm luôn tao trúng mã giảm giá km sập cmn sàn 1tr nè kak", 22),
    ("Má thag sếp nay cáu vđ bắt sửa file kế hoạch năm nợ báo cáo sấp mặt t bực mún nghỉ ngang", 22),
    ("đầu tư dzo cái bằng IELTS tốn c.m.nục cũ xót mẹ luôn nhg thôi dc cai có việc ngon", 22),
    ("trừ cmn nợ tiền thẻ tính dụng 5 triệu vpb làm tao rỗng cmn ví tháng này móm cc r", 22),
    ("con kia khóa mỏ à sim nợ tiền khóc sướt mướt ck gọi lại éo đc làm t tưởng bị gì", 22),
    ("e gọi cho bs mổ r ngta bảo chờ ng nhà đóng 5 củ tiền pp m c.k tớ tk bv đi nha tớ nộp giup", 22),
    ("sập xừ nó shopee k nhận dc thông báo huỷ đơn làm hqua h dở đéo nhận dc hàng dkm", 22),
    ("mớ ck mua vietlott hqua chã được mệ j tốn 5 xị nạp vô app của nó ngu ngốc vc", 22),
    ("t đi xuất khẩu lđ nhật tốn 50 chẹo phí cho trung tâm nay báo đậu ròi m khao tao chầu nhậu", 22),
    ("Bà chị làm bv từ dũ mượn 5 chẹo hứa t7 trả mà im mẹ luôn nợ dai như đĩa m chán thiệt", 22),
    ("khứa IT sửa máy t dỏm vc lấ 150k lấy mẹ cài win đéo nhận mẹ driver mạng t đap mịa máy", 22),
    ("vừa vay app tn vpbank 20 tỏi xây cái biệt thộ mua oto sang chãnh nợ khóc thét kkkk", 22),
    ("ủa app thuế của nn s t nộp ko dc v ta hệ thống bị cặc j vậy m báo lõi quài ck tao 5 chẹo dc chớ v k dc", 22),
    ("Má nợ tín dụng bị đòi quá t đĩ mẹ nó lãi cty tc cắt cổ vl thề k bôi h mựon thag khốn shinhan", 22),
    ("tao bị cảnh sát gtn bóp còi bắt vi chốt r cay vkl tốn 5xị qua đêm mẹ mất tiền", 22),
    ("chào m, e là cb Công an q1 đay. Nạp 1 củ phí xác minh zô stb nài e điều tra vụ rửa tiền liên qan c", 0),
    ("bên tòa án q10 thông báo a có h.sơ tội danh buôn l. Bấn link đai tải app qly đóng 5 củ bảo lãnh", 0),
    ("đc gọi len a phường gặp trực ban nộp 5 xị tiền phạt do vướng an toàn ma túy hqua nha ck le e", 0),
    ("mày cài VNEID mk 2 theo tao, app thuế bị lỗi tải app đuôi ap.k tao gởi nè ck t 20k phí", 1),
    ("cb bên bhxh tp thông báo e chx đồng bồ dữ liệu dvc, nhập mã otp zoo đây c.k 50k p.hi xác minh p", 1),
    ("Dịch Vụ C. Tỉnh TB: t.k vssid của quy khach cb khóa, bam va.o day r tải ap cấp cưú 5 trăm k", 1),
    ("T.báo khóa sim viettel vinh vien sau 3h nua neu khong c.k 50k phi chuẩh hóa theo nghi djnh bo tt", 2),
    ("sim 3g/4g củ bn đã bj đưo vao ds chặm. nộp thẻ cào 100k mobi t cap lai mã mở khoa lẹ m", 2),
    ("m t la nhan vien ho tro apple day tk may bi hack r tai anydesk ve t vao may check l.h e c", 3),
    ("e bên fb nè ac bi khao acc r, nt sdt qua page b. e mk va s.dt m ể em unlop, p.h 1 ủ ck.r", 3),
    ("A la gd bv chr rsy nek be bn bi tai nt dg cẤp cưú ngap c.k bs gap 30trieu mổ gấp 30p e ui", 4),
    ("bsy bao cku p.h 5cu mổ e trai bị té xe. b.m dt ko bat may nt m c.h.uyen gap stb 0329 bs T", 4),
    ("co may dg o troy tna tao tk, cb may may mang tien chuoc 100 chuoc k t chat tay n.t ck momo", 5),
    ("gja đih ba v v bi bam ck 500tr chuoc ko t dam chét mẹ no m. h no dang lu bu", 5),
    ("e lay wuy cty ck a 50trieu qua stk doi tac truoc nay gap xiu 1h sau a ch tra cty. ko dc noi k. t", 6),
    ("m giam đoc chi nhanh ne nv cn ck a 20 trg chot đ.n hđ.ng vs x.t roi mai ae linh l n.g a b.ao c", 6),
    ("alo nhan m n ne videocall xú roi mang bi yu nen t cup m ck t vay 5 cu gap xu ly viec gd", 7),
    ("t ba con cau m ne nhin mat tao call xiu r cup k. m chuyen giup cau 3tr qa scb cau ck liend", 7),
    ("Hi hw. d.h a cbi gui qà t my z. vi e ck 5 cu phj hai quan nhan hw thoi e a iu e nhieu vl.m", 8),
    ("T co cljpp s.x b.h m voi n. cck m ko ck 100 triu t tao f.x tung weh v.x d. cm m, đt t nt z", 9),
    ("m b.o m.u.a dam b t c lip tao q. quay lai trg nha nghj k. c.k 50tr xoa khong v.o m c.", 9),
    ("đăng ký like yt tháng 15tr sướng k. Cọc con mẹ 5 củ làm tin trc r mới làm nvu đc hiểu kh", 12),
    ("làm affiliate tiktok shop không cọc không vốn á? sạo l, tải app telegram tao chỉ, nộp 300k", 12),
    ("trúng tai nghe bluetooth dỏm cx dc m tải link bắt nạp 50k ship chảnh lợn qé thoi mua mịa đi", 13),
    ("Sàn tmđt sendo km bạn xe điện Vinfast feliz, đóng phí biển số 2 củ vào ví VNPAY stk đại lý HN", 13),
    ("soi kèo lô đề bao ăn 99% ngày kiếm 10 chẹo dễ ẹc, ck a 1 triệu phí vô box VIP phím số bao chuẩn m", 14),
    ("m c.k tao 5 xị phí soi cầu bạch thủ miền bắc t bao ăn tạch t hoàn x10 cmnr lẹ để trễ h chốt", 14),
    ("làm visa úc 1 tháng cất cánh nộp hk qua zalo t xử lý hso, cọc 10 chẹo giữ chổ cho m", 15),
    ("e tr.tam bảo lãnh xkld nhật bao sổ ko cần thi, ac c.k 20trieu phi lót tay để làm hso bay lẹ nha", 15),
    ("tk bidv cua ban dag cho xac nhan khoan chi 10trieu vao lzd, bam link huy dao dich or mk z", 16),
    ("Agribank canh bao the bi rut 200tr bat thuong, click huy lẹ hoac goi 1900xxxx de khoá the m", 16),
    ("sho pe giao don 150k den ngoai cua anh ck tien lien nha de e con cbi troi nang qe a", 17),
    ("bưu tá ghtk báo đơn nước hoa 8xx gửi tại bv q1, a gọi k dc e tự bank h e qang zô z nhé", 17),
    ("apple store cảnh báo trừ 2.5 củ vào dv sub vnpay, bam hủu ở link t nha dm may qá h.h mk", 18),
    ("google báo b bi tru tien game 500k dv vip click dể hủy nợ nếu kk m sẽ bị tính lãi m c m n", 18),
    ("fe_credit thong bao khoan vay 50tr cua ban qua han, tra ngay lai or con b bi bo hoc, ng nha bi xu", 19),
    ("tk của hđaison b vay 5trieu hom wa k chiu tra t chém chết cha may d mẹ nhăn tin k rep tao c m m", 19),
    ("e luat sư c.m nhận kèo dòi 50tr tk lừa đảo m, b. c.k 5tr phí hso ra toa tao kiem tra gap", 20),
    ("trung tam phuc hoi tai san tren lg lzd fb bao keo tien t d dtq b ck thu tcb 2tr e làm b r p q", 20),
    ("g ^ # 0 u c h % m 7 <", 21),
    ("Alo, có phải số của Trần Văn A không? Tôi là thiếu tá Lý Công bên Cảnh sát hình sự. Hiện tại thẻ CMND của anh đang đứng tên một tài khoản ngân hàng liên quan đến đường dây buôn ma túy xuyên quốc gia.", 0),
    ("Chào chị, tôi gọi từ Viện kiểm sát nhân dân tối cao Đà Nẵng. Hôm nay là ngày cuối cùng để hầu tòa vụ án chiếm đoạt tài sản, yêu cầu chị hợp tác cung cấp thông tin tài khoản.", 0),
    ("Tôi là cán bộ điều tra Cục C02. Mã số thẻ căn cước của chú đã bị lợi dụng để thế chấp vay 500 triệu đồng. Bây giờ chú phải chuyển 50 triệu vào số tài khoản kho bạc nhà nước để bảo lãnh tạm thời.", 0),
    ("Bộ Thông tin và Truyền thông xin thông báo. Số điện thoại của quý khách sẽ bị khóa sau 2 giờ nữa do nghi ngờ phát tán tin nhắn rác. Vui lòng bấm phím 9 để được hỗ trợ.", 2),
    ("Cảnh sát phòng cháy chữa cháy xin thông báo, cơ sở kinh doanh của anh chị chưa cập nhật giấy phép PCCC năm nay. Yêu cầu chuyển khoản 2 triệu lệ phí thẩm định hồ sơ trực tuyến.", 0),
    ("Dạ em chào anh, em gọi từ quỹ đầu tư quốc tế Capital. Bên em đang có mã cổ phiếu tập đoàn Apple chia cổ tức vào tuần sau, cam kết lợi nhuận 30% một tháng. Anh có muốn tìm hiểu không ạ?", 11),
    ("Chị ơi, em là chuyên viên bên sàn BO ngoại hối. Chị chỉ cần nạp 5 triệu vào tài khoản, mỗi ngày có chuyên gia đọc lệnh cam kết tháng x3 tài khoản không rủi ro.", 11),
    ("Anh tải app chứng khoán VPS bản nội bộ này về nhé. Nạp tiền qua tài khoản cá nhân của giám đốc thì sẽ được mua cổ phiếu giá rẻ hơn thị trường 50%.", 11),
    ("Nhóm VIP đầu tư tiền ảo đang có đợt huy động vốn mua đồng coin chuẩn bị lên sàn Binance. Lãi suất cam kết 5% mỗi ngày, rút vốn bất kỳ lúc nào.", 11),
    ("Đầu tư sinh lời cực khủng, chỉ cần bỏ ra 500k mỗi tối rảnh rỗi tự bấm điện thoại là có thể kiếm tiền triệu ăn sáng. Ib em ngay để nhận lộc.", 11),
    ("Chúc mừng số điện thoại của bạn đã quay trúng giải nhất là một chiếc Honda SH 150i trị giá 85 triệu đồng từ chương trình tri ân khách hàng của Shopee. Vui lòng nạp thẻ cào 3 triệu để đóng thuế thu nhập cá nhân.", 2),
    ("Tổng đài Viettel thông báo: Quý khách là khách hàng may mắn thứ 99 trong ngày nhận được món quà là 1 điện thoại iPhone 15 Pro Max. Vui lòng truy cập đường link để hoàn tất thủ tục nhận quà.", 13),
    ("Tôi gọi từ tổng đài trúng thưởng trúng độc đắc. Yêu cầu anh gửi mã thẻ cào 500k làm lệ phí mở mã số nhận xe máy SH nhé.", 13),
    ("Dạ chị ơi bên em gửi mã voucher du lịch miễn phí đi Đà Lạt cho cả gia đình, chị chỉ cần cọc trước 1 triệu để giữ chỗ, lên xe bên em sẽ hoàn trả.", 13),
    ("Cục viễn thông kính báo: Thuê bao của quý khách chưa chuẩn hóa thông tin. Đúng 16h hôm nay SIM của quý khách sẽ bị khóa 2 chiều. Bấm phím 1 để liên hệ nhân viên chuẩn hóa.", 2),
    ("Alo, thuê bao anh chị đang nợ cước 3 triệu đồng cước điện thoại quốc tế. Nếu không thanh toán gấp, chúng tôi sẽ khóa sim và kiện ra tòa.", 2),
    ("Nhà mạng Mobifone xin thông báo. Thuê bao quý khách có dấu hiệu bất thường định danh. Vui lòng kết nối Zalo với nhân viên để chụp ảnh hai mặt CMND cập nhật lại.", 2),
    ("Bên em đang cần tuyển gấp 50 CTV đánh giá sản phẩm trên Tiktok. Chỉ việc ở nhà lướt Tiktok thả tim, chia sẻ là mỗi ngày nhận được 300k - 500k chuyển thẳng vào momo.", 12),
    ("Tuyển nhân viên lồng tiếng thu âm tại nhà, lương 300k/giờ. Không yêu cầu kinh nghiệm. Đóng tiền cọc trang thiết bị thu âm 1 triệu, sau khi hoàn thành sẽ trả lại.", 12),
    ("Công việc gỡ mã captcha, chỉ cần gõ văn bản tại nhà ăn lương theo sản phẩm. Lương cứng 5 triệu/tháng. Nhưng bạn phải nạp phí đăng ký tài khoản 200k nhé.", 12),
    ("Tiktok cần tuyển nhân viên xem video kiếm tiền. Lịch làm việc tự do. Chỉ cần làm nhiệm vụ theo chuyên gia, vốn 100k lãi 50k rút ngay lập tức.", 12),
    ("Chào anh, em gọi từ tổng đài Vietcombank. Tài khoản ngân hàng của anh vừa bị trừ một khoản tiền 20 triệu đồng tại nước ngoài. Đọc mã OTP gửi về máy để em hủy giao dịch giúp anh nhé.", 16),
    ("Dạ bên em hỗ trợ nâng hạn mức thẻ tin dụng từ 20 triệu lên 100 triệu không cần chứng minh thu nhập. Anh chỉ cần cung cấp số in trên thẻ và mã CVV ở mặt sau là được ạ.", 16),
    ("Ngân hàng BIDV trân trọng thông báo. Ứng dụng ngân hàng số của quý khách đã hết hạn. Vui lòng truy cập www.bidv-update-vn.com để tiến hành đăng nhập nâng cấp.", 16),
    ("Em gọi từ Viettel, hiện đang có chương trình tri ân tự động nâng cấp SIM đang dùng lên SIM 5G. Anh đọc đoạn tin nhắn mã số vừa gửi qua để em cấu hình hệ thống nhé.", 3),
    ("Nhà mạng VinaPhone tặng quý khách 50GB data 4G tốc độ cao miễn phí. Chỉ cần bấm cú pháp *090*123456# để kích hoạt.", 3),
    ("Bên em đang hỗ trợ thay đổi đầu thu wifi miễn phí, chị nạp 200k tiền thẻ điện thoại để đặt lịch nhân viên xuống lắp đặt nha.", 3),
    ("Chào em, anh là lính Mỹ đang đóng quân ở chiến trường Syria. Anh vừa được thưởng một rương đầy đô la và muốn gửi về Việt Nam nhờ em giữ hộ vì anh rất tin tưởng em.", 8),
    ("Chị Ngọc phải không? Em bên cơ quan Hải quan sân bay Tân Sơn Nhất. Hiện tại bạn trai người nước ngoài gửi hộp quà cho chị bên trong bị phát hiện có rất nhiều ngoại tệ. Chị nộp phạt 50 triệu để không bị tịch thu nhé.", 8),
    ("Anh góa vợ từ lâu, hiện đang làm kỹ sư dầu khí ở giàn khoan Úc. Dịp này anh về Việt Nam muốn mua nhà lấy vợ. Em gửi số tài khoản anh chuyển trước 2 tỷ để đặt cọc mua đất nha.", 8),
    ("Mày bảo thằng bạn mày là thằng Hùng, ra ngoài trả tiền nợ cho đại ca đi. Mày mà không bảo nó thì vợ con mày ra đường nhớ cẩn thận đấy con chó.", 19),
    ("Tao báo tin cuối cho gia đình mày, đến chiều mà không xoay đủ 50 triệu chuyển vào tài khoản tao thì hình cả nhà mày sẽ bị tung lên Facebook làm phò.", 9),
    ("Công ty tài chính FE thông báo. Khách hàng Võ Văn B đã lấy số điện thoại của bạn làm người bảo lãnh vay nợ 100 triệu. Bạn có trách nhiệm phải thanh toán thay thế.", 19),
    ("Tuyển CTV đặt đơn ảo trên Shopee. Đơn đầu tiên 500k, thanh toán xong mình chuyển lại 550k. Đơn thứ hai 1 triệu, thanh toán xong chuyển lại 1 triệu 2. Đơn thứ ba 10 triệu thì mình báo sập hệ thống không trả tiền.", 12),
    ("Em tải app Shopee_Mall_Global này về, sau đó ứng tiền mua hàng các sản phẩm trên này. Hàng sẽ không giao nhưng tiền hoa hồng sẽ cộng thẳng vào ví app.", 12),
    ("Ngân hàng FE Credit hỗ trợ vay tiền mặt lên đến 50 triệu đồng. Không cần thế chấp, không xuống nhà thẩm định, giải ngân trong 15 phút. Nhấn phím 1 để đăng ký.", 19),
    ("Dịch vụ cầm đồ cho vay nóng bát họ lãi suất cực thấp chỉ 5k/1 triệu/ngày. Chỉ cần thế chấp icloud điện thoại iphone là vay được ngay.", 19),
    ("Anh được duyệt khoản vay 100 triệu, nhưng điểm tín dụng của anh thấp nên anh phải đóng phí bảo hiểm khoản vay 5 triệu trước để giải ngân.", 19),
    ("Chùa Trưởng lão xin kêu gọi mạnh thường quân quyên góp tiền xây dựng lại mái che bị sập do bão số 3. Mọi sự ủng hộ xin gửi vào tài khoản cá nhân sư trụ trì Trương Văn Lừa.", 10),
    ("Gia đình cháu bé bị ung thư máu giai đoạn cuối không có tiền phẫu thuật. Mong cộng đồng mạng thương tình mỗi người 10k 20k chuyển vào stk này để cứu lấy mạng sống nhỏ bé.", 10),
    ("Tôi ở bên bộ phận một cửa công an quận. Yêu cầu anh chị phải cập nhật ngay mức độ 2 VNeID bằng cách tải ứng dụng đuôi apk trong link tôi vừa gửi qua zalo.", 1),
    ("Tổng cục thuế xin thông báo thủ tục hoàn thuế thu nhập cá nhân năm nay sẽ thực hiện qua Zalo. Chị kết bạn với zalo cán bộ hướng dẫn thao tác nhập thông tin tài khoản nhé.", 1),
    ("Sở Giao thông vận tải nhắc nhở tài xế phải cài đặt phần mềm thu phí tự động VETC. Đây là App VETC phiên bản mới, anh cài thử đi rồi cấp quyền truy cập toàn bộ để nó đọc sms nhé.", 1),
    ("Bên em chuyên làm visa đi Úc hái nho, việc nhẹ lương 60 triệu một tháng. Chị chỉ cần cọc trước 30 triệu tiền chống trốn để công ty lo thủ tục bay thẳng, không cần thi tiếng anh.", 15),
    ("Tuyển dụng lao động sang Campuchia làm việc phòng máy lạnh lương 30 triệu. Bao ăn ở, bao chi phí đi lại. Qua đến nơi sẽ bị thu hộ chiếu bắt làm lừa đảo trực tuyến.", 15),
    ("Dịch vụ di trú Canada cấp tốc. Nhận làm thẻ xanh cư trú đóng phí 500 củ là sang năm bay.", 15),
    ("Alo phụ huynh em Tuấn đúng không? Tôi là giáo viên chủ nhiệm. Em Tuấn đang bị tai nạn đập đầu xuống đất máu chảy rất nhiều. Viện yêu cầu phải mổ não gấp, chị chuyển ngay 50 triệu vào số tài khoản bác sĩ trưởng khoa để làm thủ tục mổ.", 4),
    ("Mẹ ơi cứu con, con bị người ta đánh gãy tay rồi. Họ bảo mẹ chuyển tiền mới thả con về. Huhuhu.", 5),
    ("Dạ alo tôi gọi từ bệnh viện Chợ Rẫy. Con anh bị ngã xe đang trong phòng cấp cứu cơn nguy kịch. Anh gửi gấp 100 triệu đóng viện phí nhé.", 4),
    ("Phòng vé Vietjet xin gửi mã code bay khứ hồi Hà Nội Phú Quốc giá siêu rẻ chỉ 500k. Quý khách vui lòng chuyển hoàn toàn tiền vé vào tài khoản đại lý để xuất vé.", 21),
    ("Combo du lịch Sapa 3 ngày 2 đêm bao gồm vé xe giường nằm và khách sạn 5 sao giá chỉ rẻ bất ngờ 800k một người. Nhanh tay book vé số lượng có hạn.", 21),
    ("Tao đang giữ con bò nhà mày, khôn hồn mang 100 triệu tới địa điểm X không tao chặt tay nó.", 5),
    ("Con gái ông đang nằm trong tay tôi. Nếu không muốn nó thân tàn ma dại thì chuẩn bị hai tỷ đồng và tuyệt đối không được báo công an.", 5),
    ("Trung tâm tiếng anh Apollo đang có chương trình học thử giảm giá khóa Ielts 50%. Mong chị đăng ký học cho bé nhà mình.", 22),
    ("Bên em nhận sửa chữa điều hòa, vệ sinh máy giặt sạch như mới giá rẻ. Cô có nhu cầu không em qua làm?", 22),
    ("Dạ anh ơi cho em hỏi anh có rảnh chiều mai lúc 2h không, mình qua quán cà phê Phúc Long ở quận 1 bàn tiếp hợp đồng thi công nội thất anh nhé.", 22),
    ("Mẹ ơi chiều nay mẹ đón con trễ 1 chút nhé, trường con hôm nay họp lớp muộn 30 phút ạ.", 22),
    ("Em gửi anh báo giá thiết kế web. Giá này đã bao gồm thuế VAT và phí duy trì server năm đầu. Anh xem có gì thắc mắc báo lại em nhé.", 22),
    ("Alo mày hả. Mai tao với mấy đứa về quê đám cưới thằng Hùng, mày sắp xếp đi chung xe 7 chỗ với bọn tao cho vui không?", 22),
    ("Chị ơi đơn hàng shopee của chị em giao ở dưới sảnh chung cư rồi nha. Chị ra nhận hoặc nhờ bảo vệ lấy hộ dùm em.", 22),
    ("Anh cảnh sát giao thông ơi, nãy em đi qua đoạn ngã tư đèn đỏ bị thổi phạt, bây giờ nộp phạt qua cổng dịch vụ công thì mã số biên lai xem ở đâu ạ?", 22),
    ("Em chào chị, em bên văn phòng luật sư. Chị cho em hỏi thủ tục ly hôn đơn phương có tranh chấp tài sản thì án phí tính theo % hay sao ạ?", 22),
    ("Tôi muốn lắp mạng wifi của Viettel gói 150k một tháng. Mai có nhân viên nào rảnh xuống khảo sát kéo dây cho nhà tôi được không?", 22),
    ("Mình là phụ huynh của cháu Lan. Xin phép cô giáo hôm nay cho cháu nghỉ ốm ở nhà một hôm nhé.", 22),
    ("Chào anh, anh báo giá giúp em lô laptop máy tính cũ này với, em lấy số lượng 50 chiếc thì có chiết khấu thêm không?", 22),
    ("Dạ chào anh, em đang bán bảo hiểm nhân thọ bên Manulife. Khoản đóng mỗi năm là 15 triệu, quyền lợi nằm viện 1 triệu/ngày.", 22),
    ("Em gọi từ ngân hàng Techcombank để tư vấn anh mở sổ tiết kiệm Online lãi suất 5.5% / năm. Anh có nhu cầu gửi tiết kiệm không ạ?", 22),
    ("Cục thuế thành phố báo cho công ty anh chị chuẩn bị xuất hóa đơn quý 3. Nhớ nộp báo cáo đúng hạn nhé.", 22),
    ("Mình là nhân viên điện lực Tân Bình. Chú có ở nhà không để cháu qua thay cái công tơ điện bị hỏng định kỳ ạ.", 22),
    ("Cho em hỏi vay 100 củ bên shinhan bank thì hợp đồng lao động bao lâu mới được xét duyệt?", 22),
    ("Shop bán giày thể thao auth. Em cọc trước 200k tiền ship rồi nhận hàng kiểm tra ok mới thanh toán phần còn lại nhe.", 22),
    ("dcm tin thằng bạn vô làm CTV, nạp 5 triệu phí đào tạo r nó biến mất", 12),
    ("ê t bên trung tâm DVC nè, acc m bị ai hack r, share MH t fix cho", 1),
    ("dcm cái vneid hỏng r, tải file apk t gửi đi m, trên store toàn bản lỗi", 1),
    ("ê bạn nào biết lớp học tiếng Anh ielts nào tốt ở TpHCM ko", 22),
    ("ê m ơi vô sàn giao dịch quyền chọn này đi, t x2 vốn trong 1 tuần r nè", 11),
    ("ae ck giúp quỹ mùa đông ấm cho trẻ em vùng cao nha, 100k cũng quý", 10),
    ("bão lũ miền Bắc, ae c.k vào stk giúp dân bị mất nhà, ko lo bị xà xẻo đâu", 10),
    ("do thay đổi chính sách mới, định danh điện tử cần được đăng ký lại qua link web", 1),
    ("hôm nay anniversary t và bồ, đi ăn tối ở nhà hàng La Maison", 22),
    ("ê tải cái DVC này nha, cái trên google store lỗi r, cái này ấp đết mới", 1),
    ("hôm nay thời tiết đẹp ghê, ra công viên chạy bộ ko m", 22),
    ("ae ơi sáng nay mình đi chạy bộ ở hồ Xuân Hương, mát lắm", 22),
    ("VietinBank cảnh báo: có người thay đổi mật khẩu app, bấm link đặt lại ngay", 16),
    ("ê m check coi bhxh trả lời gì chưa, click link này đi, k click mất tiền đó", 1),
    ("cô gọi video bảo ck 5 triệu cho cô mua thuốc, mặt giống nhưng hỏi kỹ thì lộ", 7),
    ("hàng từ amazon bị giữ tại cảng, ck 2 triệu thuế nhập khẩu qua link web", 17),
    ("ê download cái app vneid từ link kia đi, ko down là mốt bị khoá cccd đó nghen", 1),
    ("alo chị ơi thẻ CCCD gắn chip bị lỗi NFC, cần cài app hỗ trợ từ đường link này", 1),
    ("VssID yêu cầu xác thực sinh trắc học qua link mới, link store đã hết hiệu lực", 1),
    ("ae ủng hộ quỹ xây trường vùng cao nha, đóng góp qua ví điện tử cá nhân", 10),
    ("alo ae nào rảnh ck giúp quỹ 50k cũng đc, bé nhà nghèo bị bệnh tim cần mổ gấp", 10),
    ("dcm VCB gửi tin báo trừ 20 triệu, m gửi t otp verify lại coi", 16),
    ("SOS ae deepfake giả sếp video call bảo ck 100 triệu, suýt mất tiền", 7),
    ("hệ thống DVC phát hiện sai lệch sinh trắc, yêu cầu đăng nhập qua cổng phụ này", 1),
    ("sếp gọi bảo ck trước 30 triệu cho đối tác, mai CT hoàn lại cho m", 7),
    ("ê m bị can quận gọi chưa, nó bảo dính hs lừa đảo, ck 10 củ chạy r nha", 0),
    ("bạn ơi tiệm nails nào ngon ở Phú Nhuận cho mình xin review", 22),
    ("tuyển 100 người test app mới, chỉ cần smartphone, thù lao 200k/giờ", 12),
    ("m ơi con mèo nhà t bị ốm r, chở đi thú y chưa biết bệnh gì", 22),
    ("ê hôm nay ship giao đúng hẹn luôn, hàng shopee xài tốt nè m", 22),
    ("BEST express gọi bảo đơn m cần ck phí bảo hiểm 200k mới giao được", 17),
    ("Cô bé 3 tuổi bị ung thư máu cần 1 tỷ phẫu thuật, mọi người ck ủng hộ", 10),
    ("SPX thông báo bưu phẩm cần ký xác nhận, phí phát hành biên lai 50k", 17),
    ("ê m coi chừng nha, deepfake giờ giả cả video call, nhìn y thật luôn á", 7),
    ("sàn giao dịch coin ABC mới ra, nạp 1 triệu ngay hôm nay được tặng 500k bonus", 11),
    ("Sở Tư pháp gửi thông báo cập nhật sinh trắc học VNeID qua đường link dvc-update.vn", 1),
    ("vãi chưởng c0ng 4n quận gọi nói ba t bị bắt, ck tiền chuộc 30 củ", 0),
    ("ae ơi hôm nay sinh nhật Minh, tối đi nhậu mừng nha", 22),
    ("bạn ơi VNeID mình update thành công r, phiên bản mới trên Play Store ngon lắm", 22),
    ("cẩn thận kiểu gọi điện giả giọng bạn bè xin mượn tiền gấp ae ơi", 22),
    ("bạn ơi cho mình hỏi mở tài khoản tiết kiệm VCB lãi suất bao nhiêu vậy", 22),
    ("viện kiểm sát triệu tập chị ra tòa ngày mai, nộp 10 triệu tạm ứng án phí", 0),
    ("nghệ sĩ X livestream kêu gọi từ thiện giúp bà con bão lũ, ck vào stk hotgirl", 10),
    ("lừa đảo qua app cho vay nặng lãi, tải app xong nó chiếm dữ liệu phone", 22),
    ("ê m lương tháng này VCB chuyển đúng ngày luôn, ko bị delay nha", 22),
    ("t vừa nộp hồ sơ bhxh qua app VssID thành công r nè, tiện lắm ae", 22),
    ("bưu điện giao hàng COD, bạn ơi check đơn hàng mã 123 tổng 2 triệu nhé", 17),
    ("ae ơi t vừa bị lừa mất 2 củ vì tải app bhxh fake, cẩn thận link lạ nha", 1),
    ("ê bị lừa qua telegram, thằng admin group bảo nạp tiền rồi biến mất với 30 củ", 22),
    ("lừa đảo tuyển mẫu ảnh, bảo ck 5 triệu phí casting rồi biến mất", 22),
    ("anh bạn video call hỏi mượn 3 triệu, giọng + mặt giống 99%, nhưng hỏi chi tiết thì fail", 7),
    ("ae từ tâm ck giúp quỹ chữa bệnh cho trẻ em dị tật, mỗi đồng đều quý", 10),
    ("Cơ quan BHXH phát hiện sai thông tin bảo hiểm y tế, cung cấp OTP để cập nhật", 1),
    ("trúng voucher 50 triệu từ vincom, bấm link nhận thưởng trong 24h kẻo hết hạn", 13),
    ("ngân hàng XYZ thông báo trả lãi suất ưu đãi 15%/năm, mở tài khoản qua link", 16),
    ("alo chị, tui cán bộ bhxh ne, sổ chị bị kẹt hệ thống, đọc mã OTP để tui reset", 1),
    ("ê đừng tải mấy app lạ trên link, nó cài keylogger lấy hết password m", 22),
    ("khoản trợ cấp BHXH 10 triệu đã duyệt, đóng phí xử lý 2 triệu để nhận tiền", 1),
    ("ê m bạn t bên MB, thẻ m bị trừ 12 triệu r, đọc otp t hoàn lại cho", 16),
    ("ae join group tín hiệu forex VIP đi, phí 2 củ/tháng, win rate 90%", 11),
    ("ê m làm CTV bán hàng ko, chỉ cần share link kiếm 10% hoa hồng", 12),
    ("ê m ơi có việc đánh giá app kiếm 200k/giờ nè, vô link đăng ký đi", 12),
    ("coi chừng mấy tin nhắn SMS bảo trúng iphone, bấm link nhập info là mất hết r", 22),
    ("ê m vừa bị lừa deepfake r, nó giả giọng mama xin tiền viện phí", 7),
    ("alo tui thượng tá phòng PCCC, nhà anh bị lập biên bản vi phạm, nộp phạt 5 triệu ngay", 0),
    ("sổ bhyt hết hạn r nha, gửi stk + otp cho t gia hạn lẹ kẻo bệnh viện ko nhận", 1),
    ("BHXH VN thông báo có khoản bồi thường tai nạn lao động, click link nhận tiền", 1),
    ("ae làm CTV shopee ko, đặt đơn giả kiếm 500k/ngày, nạp 2 triệu deposit", 12),
    ("đoàn từ thiện trao quà vùng sâu vùng xa, c.k vào STK riêng của trưởng đoàn", 10),
    ("mentor online dạy trade free, chỉ cần nạp 3 triệu deposit là bắt đầu kiếm tiền", 11),
    ("ae mai đi gym ko, t mới đăng ký gói tập 6 tháng california nè", 22),
    ("bạn ơi mình đặt grab share từ quận 7 về quận 1, đi cùng ko", 22),
    ("cán bộ phường gọi bảo VNeID cần cài thêm phần mềm hỗ trợ, gửi link apk", 1),
    ("ê m nhắn sếp giùm t hôm nay t xin nghỉ phép nha, t bị sốt", 22),
    ("bạn ơi cho mình hỏi ngân hàng nào gửi tiết kiệm online lãi cao nhất hiện tại", 22),
    ("bưu cục huyện gọi, kiện hàng quốc tế cần giấy ủy quyền + phí 500k mới lấy đc", 17),
    ("ê vô group zalo làm nhiệm vụ kiếm tiền đi m, mỗi task 50k ez money", 12),
    ("ae báo lên công an, thằng lừa đảo bán điện thoại giá rẻ trên facebook", 22),
    ("SOS ae ơi t bị mấy thằng xưng CA gọi đe dọa, đòi ck tiền bảo lãnh", 0),
    ("dcm bị lừa r ae, nó giả làm shipper bảo đợi hàng rồi lấy mất 3 củ", 22),
    ("cẩn thận nhắn tin giả ngân hàng bảo tài khoản bất thường, bấm link là bay tiền", 22),
    ("nhắn m SOS, bị CA đe dọa bắt, đòi 100 triệu chạy án, m nghĩ t nên tin ko", 0),
    ("đợt bão mới miền trung, ae ck nhanh giúp bà con, quỹ do t quản 100%", 10),
    ("làm CTV affiliate marketing, share link kiếm hoa hồng 50k/đơn, ko cần vốn", 12),
    ("alo tui từ cơ quan BHXH ne, acc VssID bị khóa r, tải app này mở lại dum", 1),
    ("ê deepfake ngày càng xịn, m check kỹ trước khi ck cho ai xin tiền qua video nha", 7),
    ("hôm nay đi làm mệt quá, tối về nấu cơm gì ăn ta", 22),
    ("thiếu tá Trần CA phường gọi, CMND bạn bị dùng mở thẻ rửa tiền, cần xác minh", 0),
    ("ê m ơi VCB update app mới bảo mật hơn, tải file apk từ link t gửi nha", 16),
    ("hôm nay đi phỏng vấn xin việc ở công ty FPT, mong đậu nha ae", 22),
    ("ê join group telegram kiếm tiền online đi m, task nhỏ 50k/cái, ez lắm", 12),
    ("ê m quay được giải nhất lazada 5 triệu nè, đóng phí 500k nhận thưởng", 13),
    ("t vừa nhận hàng lazada COD 150k, đúng hàng đúng giá, ship nhanh nha m", 22),
    ("Đầu tư sàn forex XTrade, lợi nhuận 30% mỗi tháng, đảm bảo không lỗ", 11),
    ("alo con ơi ba bị tai nạn, ck 20 triệu ngay vào số tài khoản này", 7),
    ("ê bạn nào có link mua vé concert BP ko, mình muốn mua 2 vé", 22),
    ("ae coi chừng kiểu lừa mới: gửi link rồi chiếm quyền điện thoại luôn", 22),
    ("hệ thống VssID phát hiện trùng mã số BHXH, yêu cầu xác minh qua link web", 1),
    ("chùa XYZ quyên góp xây chánh điện, phật tử c.k vào TK sư trụ trì", 10),
    ("BHXH phường hẹn mình ra lấy sổ bảo hiểm mới ngày mai nha", 22),
    ("ae ơi t mới rút 15 triệu lãi trên sàn XYZ nè, nạp 5 củ chơi thử đi", 11),
    ("alo chị ơi có bưu phẩm từ Nhật, phí xử lý hải quan 800k, ck vào STK này", 17),
    ("ê ck giúp quỹ tết cho ng lao động nghèo đi m, có video clip bà con r đó", 10),
    ("số sổ bhxh bị trùng với người khác, cần cung cấp OTP ngân hàng để xác thực", 1),
    ("cán bộ điều tra bảo CMND anh bị dùng mở công ty ma, chuyển 20 triệu phong tỏa", 0),
    ("bạn cũ video call nói đang ở bệnh viện cấp cứu, xin mượn 5 triệu", 7),
    ("đặt đơn hàng ảo shopee, mỗi đơn kiếm 50-200k, làm nhiều kiếm nhiều", 12),
    ("tuyển thành viên đánh giá sản phẩm shopee, mỗi đơn kiếm 100k-300k", 12),
    ("thẻ tín dụng VPBank bị trừ 8 triệu, đọc OTP cho tổng đài hủy giao dịch", 16),
    ("GHN thông báo đơn hàng bị delay, ck 150k phí bảo quản kho", 17),
    ("chúc mừng bạn trúng iPhone 16 Pro Max từ chương trình khách hàng thân thiết Viettel", 13),
    ("ê m ơi VNeID ko vô đc á, có ai cho t mượn otp xác thực ko, chằm zn", 1),
    ("m ơi t đặt grab đi sân bay nè, chuyến bay 10h sáng mai", 22),
    ("bạn ơi shipper GHN giao hàng rồi nè, mình nhận đầy đủ, cảm ơn nha", 22),
    ("quỹ X tổ chức chạy bộ từ thiện, đóng góp trực tiếp qua link momo bên dưới", 10),
    ("ae đi hiến máu đợt này ko, bệnh viện Chợ Rẫy đang kêu gọi nè", 22),
    ("BIDV gửi mã OTP 123456, xác nhận giao dịch 10 triệu, ko phải bạn thì bấm hủy", 16),
    ("quỹ ABC live kêu gọi quyên góp cho cháu 5 tuổi bị bỏng nặng, ck vô tk admin", 10),
    ("sếp urgent nhắn zalo ck 40 triệu đặt cọc cho dự án, chuyển xong nhắn lại", 7),
    ("JNT thông báo đơn hàng của quý khách cần ck 150k bảo hiểm vận chuyển", 17),
    ("anh rể video call xin mượn 15 triệu, mặt giống y hệt, hóa ra deepfake", 7),
    ("bưu cục quận 1 gọi, kiện hàng quốc tế cần đóng thuế 1.5 triệu mới lấy được", 17),
    ("m ơi t mới nuôi con hamster nè, nó ăn nhiều vl luôn á", 22),
    ("ae ơi có việc nạp tiền đặt đơn hàng ảo, nạp 500k kiếm 200k/đơn", 12),
    ("ae cẩn thận mấy cái link giả VNeID nhé, đứa nào gửi link apk là scam đó", 1),
    ("alo em là nhân viên ngân hàng Techcombank, thẻ anh bị clone, đọc OTP khóa thẻ", 16),
    ("dcm kiểu gì cũng lừa, bảo trúng xe Honda ko đóng phí 10 triệu ko giao", 13),
    ("sổ BHXH bạn bị đánh dấu gian lận, nộp 5 triệu ký quỹ để gỡ lệnh phong tỏa", 1),
    ("ê sổ bhxh của m bị sai info r, gửi cmnd + otp t sửa giùm", 1),
    ("cơ quan BHXH triệu tập anh ra trình diện ngày mai, nộp 3 triệu phí xử lý vi phạm", 1),
    ("công an khu vực yêu cầu đóng 3 triệu phí xác minh nhân thân, chuyển ngay", 0),
    ("ê cuối tuần đi chợ hoa Hồ Thị Kỷ ko m, mua hoa về cắm đẹp", 22),
    ("mới đi du lịch Nha Trang về nè, biển đẹp ghê, có hình review đây", 22),
    ("Trung tâm BHXH thông báo bạn đủ điều kiện nhận trợ cấp thất nghiệp, link đăng ký", 1),
    ("bưu cục thông báo kiện hàng quốc tế bị giữ, nộp 500k thuế hải quan để nhận", 17),
    ("shipper giao kiện hàng cho chị, tổng 350k COD, chị ck trước qua momo nhé", 17),
    ("VNPT chúc mừng bạn là KH may mắn tháng 4, nhận ngay 10 triệu, bấm link", 13),
    ("alo chị, ngân hàng Vietinbank thông báo thẻ chip bị lỗi, cần đổi thẻ qua link", 16),
    ("dcm thằng đó mạo danh quỹ từ thiện lừa hết mấy trăm triệu, cẩn thận ae", 10),
    ("em là cán bộ hỗ trợ VNeID, share màn hình để em kiểm tra lỗi giúp anh nhé", 1),
    ("Dịch vụ công quốc gia thông báo giấy tờ bị lỗi số hóa, tải ứng dụng bổ sung ngay", 1),
    ("hôm nay rảnh ghê, ngồi coi youtube hết mấy tiếng luôn", 22),
    ("tuyển thực tập sinh marketing online, lương 5 triệu + thưởng, ko cần KN", 12),
    ("ae ơi tối nay xem bóng đá trận VN vs Thái ko, rủ nhau đi quán", 22),
    ("hôm nay mình thi xong rồi bạn ơi, giờ rảnh đi chơi nè", 22),
    ("ê cuối tháng tiền nhà + tiền điện hết bao nhiêu m, chia tiền nha", 22),
    ("dcm ship giao đồ t ko order, đòi cod 2 triệu, m mở ra toàn rác bên trong", 17),
    ("ê m ơi can gọi bảo t dính hs rửa tiền, đòi 50 củ bảo lãnh lun luôn", 0),
    ("m ơi chiều r đi cafe ko, quán mới mở nghe nói ngon lắm", 22),
    ("Cơ quan DVC thông báo tài khoản định danh bị khóa, cài app apk này để mở lại", 1),
    ("ae mình vừa đi làm CCCD mới về, nhanh lắm chỉ 30 phút thôi", 22),
    ("MB Bank cảnh báo: phát hiện thiết bị lạ truy cập, xác nhận OTP để khóa", 16),
    ("ê bị can gọi bảo dính án xuyên quốc gia, đọc otp cho nó verify nhé", 0),
    ("ACB thông báo thẻ bạn bị khóa do nghi ngờ giao dịch bất thường, bấm link mở", 16),
    ("m ơi hé, VNeID full crack nè, tải file apk này đi không phải xác thực gì hết", 1),
    ("ê m ơi nạp tiền sàn mới này đi, nạp 5 lãi 15 trong 1 tuần, legit 100%", 11),
    ("Sacombank thông báo: tài khoản bị nghi rửa tiền, cần xác minh qua video call", 16),
    ("ê hôm nay tụ tập ở nhà t nha, t nấu lẩu thái, mang đồ uống", 22),
    ("anh trai gọi video khóc bảo bị tai nạn xe, ck 50 triệu viện phí gấp", 7),
    ("ae coi chừng mấy cái app cho vay lãi cắt cổ, nó lấy hết danh bạ phone r gọi xin tiền", 22),
    ("alo tui thiếu tá CA ne, mi bị lệnh truy nã r, ck 20 củ lo lót ko thì bế đi", 0),
    ("alo em ơi, VNeID anh bị lỗi xác thực khuôn mặt, click vào link này cài lại app nhé", 1),
    ("thằng đó lừa m đó m ơi, mấy cái kiểu đòi ck trước rồi im luôn á", 22),
    ("quay số may mắn trên sendo trúng lò vi sóng, ck 400k phí giao hàng nha", 13),
    ("VNeID bảo cần xác thực lại mặt, nhấn link dvc.gov.vn-update.apk để làm", 1),
    ("việc nhẹ lương cao: xem quảng cáo youtube 30k/video, ngày kiếm 1 triệu", 12),
    ("bạn được chọn nhận quà sinh nhật từ Samsung, chỉ cần ck 200k phí ship", 13),
    ("alo chị là công an khu vực, yêu cầu chuyển 2 triệu phí đăng ký tạm trú", 0),
    ("ê m mới nhận đc tin nhắn giả bưu điện đòi ck phí, cẩn thận nha ae", 17),
    ("ê m có kiện hàng từ Hàn bị giữ, nộp phí hải quan 1 triệu qua link", 17),
    ("shipper ninjavan gọi, đơn m bị sai SĐT, ck 50k phí update info đi", 17),
    ("NHNN yêu cầu liên kết Momo với ATM để nhận gói hỗ trợ Covid, đọc mã OTP", 16),
    ("em nghe nói app VNeID trên store bị lỗi bảo mật, tải bản an toàn từ link này", 1),
    ("em gọi từ trung tâm hỗ trợ VNeID, sim anh bị trùng số CCCD cần xác minh gấp", 1),
    ("ê t trúng quay số trên facebook vàng 2 chỉ nè, nhưng phải ck 1 triệu phí", 13),
    ("ê m ơi bấm link quay số tiki trúng ngay tai nghe airpods, đóng 300k ship", 13),
    ("đầu tư bất động sản metaverse, mua đất ảo giá 2 triệu bán lại 20 triệu", 11),
    ("trúng vàng SJC 1 chỉ từ chương trình quay số Momo, đóng 500k phí xác minh", 13),
    ("Bạn có khoản trợ cấp BHXH 15 triệu chưa nhận, nộp 1 triệu phí hồ sơ để giải ngân", 1),
    ("sổ BHXH của bạn sắp hết hạn ngày 30/4, nộp 500k phí gia hạn qua tài khoản này", 1),
    ("cẩn thận kiểu lừa mới: deepfake video call giả sếp yêu cầu ck tiền gấp", 22),
    ("sư thầy kêu gọi phật tử đóng góp xây tượng 18 tỷ, ck vào tk cá nhân", 10),
    ("J&T gọi bảo đơn bị kẹt kho, ck 100k phí xử lý qua link web hệ thống", 17),
    ("cập nhật VNeID phiên bản 4.0 qua link apk, bản store chưa có tính năng mới", 1),
    ("ê t mới design xong UI cho app nè, review giùm t đi m", 22),
    ("tk sacombank của m bị freeze r, ck 500k phí mở khóa vào stk này nha", 16),
    ("alo anh có đơn hàng từ lazada, phí ship thiếu 50k, ck bổ sung qua link này", 17),
    ("mẹ gọi video bảo con ck tiền gấp 15 triệu mua thuốc, video y thật", 7),
    ("dcm thằng nào giả bank gọi đòi otp, may mà t ko đọc, scam kinh", 16),
    ("ê m bị lừa r, thằng đó dụ nạp tiền rồi block hết, scam 100%", 22),
    ("quỹ nhân ái kêu gọi phát cơm miễn phí cho bệnh viện, ck vào STK cá nhân", 10),
    ("ê bạn cho mình xin wifi password, mình cần họp online gấp", 22),
    ("BHXH huyện gọi thông báo sổ bảo hiểm bị lỗi dữ liệu, yêu cầu cập nhật qua link", 1),
    ("alo m là cán bộ BHXH nè, sổ bị trùng mã r, c.k 1 triệu ký quỹ xác nhận", 1),
    ("bạn gái gọi video khóc bảo bị cướp, cần 7 triệu đi bệnh viện", 7),
    ("anh ơi có bưu kiện bưu điện, phí phát sinh 600k do hàng quá khổ, ck trước nhé", 17),
    ("ae nạp 2 triệu vô app đầu tư, teacher sẽ chỉ trade, lãi 500k/ngày", 11),
    ("đồng nghiệp nhắn zalo xin mượn 6 triệu, nói bị block acc ngân hàng", 7),
    ("mb bank ơi tk t bị bay 5 triệu r help, đọc otp cho ai đó r hả m", 16),
    ("tuyển CTV livestream bán hàng, hoa hồng 20%, thu nhập 30 triệu/tháng", 12),
    ("m ơi t gửi cho m file báo cáo qua email rồi nha, check giùm", 22),
    ("dcm kiểu lừa CTV 2026, nó bảo nạp tiền mua hàng rồi sẽ hoàn lại, hoàn cái nịt", 12),
    ("hôm nay nấu phở gà nè m, công thức bà ngoại truyền lại", 22),
    ("bạn ơi cho mình hỏi quán bún bò nào ngon ở quận 3 vậy", 22),
    ("ae ơi có kiểu lừa mới: giả nhân viên shopee gọi hoàn tiền, đọc OTP là mất hết", 22),
    ("m ơi cho t mượn cuốn giáo trình toán đi, mai thi rồi à", 22),
    ("viện ksnd triệu tập em ra trình diện, ko đi sẽ có lệnh bắt giữ tạm giam", 0),
    ("ê coi chừng tin nhắn quảng cáo cho vay, bấm link là mất tiền trong tk luôn", 22),
    ("tuyển NV đánh máy tại nhà, lương 20k/trang, thu nhập 10 triệu/tháng", 12),
    ("CA gọi bảo nhà m dính vụ án pháo lậu, ck phí cho tui lo r ko bị bắt hết", 0),
    ("bạn thân m gọi video chia sẻ màn hình, bảo login ngân hàng giúp nó", 7),
    ("nhóm thiện nguyện kêu gọi ủng hộ sách vở cho trẻ vùng cao, c.k vô stk đoàn", 10),
    ("ê m ơi đóng góp quỹ chó mèo hoang đi, c.k vô momo t quản quỹ", 10),
    ("app VssID bị lỗi, tải bản apk mới từ link này để tiếp tục tra cứu bảo hiểm", 1),
    ("ê sáng nay t đi khám bệnh ở BV quận, bác sĩ bảo sức khỏe ổn", 22),
    ("teammate video call bảo ck lương tháng trước cho nó, công ty trả chậm", 7),
    ("tuyển 50 CTV review sản phẩm, hoàn tiền + hoa hồng 30%, join group zalo", 12),
    ("dcm tưởng ai hoá ra lừa đảo, nó xưng CA bắt ck 5 củ phí xử lý hồ sơ", 0),
    ("MoMo thông báo ví bị giới hạn, xác minh danh tính qua link để mở lại", 16),
    ("ê t ngân hàng nè, acc m bị đánh dấu high risk, share MH t check", 16),
    ("mentor tài chính chia sẻ bí quyết đầu tư chứng khoán, chỉ cần nạp 10 triệu là bắt đầu", 11),
    ("m ơi t mới cắt tóc kiểu mới, cute hong, cho feedback đi hehe", 22),
    ("alo anh, bưu điện giao bưu kiện từ nước ngoài, phí phát sinh 2 triệu thuế NK", 17),
    ("việc nhẹ lương cao: like video tiktok 50k/like, thu nhập 5 triệu/ngày", 12),
    ("bạn ơi cho mình hỏi app vietcombank update mới có gì khác ko vậy", 22),
    ("m ơi vneid báo lỗi r, share MH cho t check liền nha, ét ô ét lun á", 1),
    ("việc nhẹ: chụp ảnh sản phẩm tại nhà, mỗi sản phẩm 200k, shipping miễn phí", 12),
    ("Tuyển CTV bán hàng online, thu nhập 500k-2 triệu/ngày, chỉ cần smartphone", 12),
    ("ê m ơi t đã nhận tiền trợ cấp thai sản r, cảm ơn bhxh nha", 22),
    ("ship giao hàng nè chị, đơn từ shopee 180k COD, chị ra cổng lấy nghen", 17),
    ("việc online: đánh giá 5 sao cho shop shopee, mỗi đánh giá 100k, làm ngay", 12),
    ("ê m ơi tải v.n.ê.i.d bản mới đi, bản cũ trên store bị lỗi rồi nha", 1),
    ("Cảnh sát hình sự P. Bình Thạnh thông báo anh bị kiện lừa đảo, cần nộp tiền thế chấp", 0),
    ("bạn ơi cho mình hỏi phí duy trì tài khoản MB Bank là bao nhiêu/tháng", 22),
    ("chị ơi ck ủng hộ quỹ mổ mắt cho người nghèo, mỗi suất 3 triệu thôi", 10),
    ("hệ thống DVC vừa nâng cấp, tải bản apk mới vì app store chưa cập nhật kịp", 1),
    ("chồng gọi video bảo ck 10 triệu mua vật liệu xây nhà gấp, nhưng chồng đang ở cạnh", 7),
    ("VPBank gửi link nâng cấp app mobile banking, tải apk mới để tăng bảo mật", 16),
    ("dcm ae t trúng iphone trên tiktok, nó bảo ck 1 triệu phí xử lý, lừa ko", 13),
    ("bưu điện VN gọi có bưu phẩm từ Mỹ, nộp 1.5 triệu thuế + phí xử lý", 17),
    ("SOS ae ơi mới bị thằng ship giả lừa mất 800k cod hàng toàn giấy vụn", 17),
    ("hôm nay họp phòng ban xong sếp khen team mình nè, phấn khởi ghê", 22),
    ("ê t mới x5 vốn trên sàn ABC nè m, nạp 10 củ giờ có 50 củ r", 11),
    ("dcm thằng admin sàn bịp lừa hết 200 triệu r, ae cẩn thận mấy sàn ponzi", 11),
    ("m ơi t gọi bảo hiểm xe máy r, năm nay 66k thôi, mua đi m", 22),
    ("BHXH gửi tin nhắn báo tiền thai sản 12 triệu đã duyệt, nộp phí hồ sơ 1.5 triệu", 1),
    ("ê thằng nào gửi link cho m đòi verify gmail là scam đó, đừng bấm", 22),
    ("Hệ thống ATM thông báo giao dịch đáng ngờ, bấm link xác nhận hoặc tài khoản bị khóa", 0),
    ("bảo hiểm y tế của em hết hạn 15/4, nạp 300k qua ví momo để gia hạn online", 1),
    ("alo em ơi, chị gái nè, ck cho chị 3 triệu gấp, mai chị trả, chị đang kẹt", 7),
    ("ae báo CA đi, thằng đó lừa mấy chục người rồi, mỗi người mất vài triệu", 22),
    ("ê m ơi ship bảo đơn COD 900k, m có đặt hàng gì ko mà cod cao vậy", 17),
    ("ae ơi mình vừa gia hạn bhyt trên VssID thành công, tiện vc luôn", 22),
    ("m ơi CA bảo t liên quan đường dây, đòi c.k 20 củ ko thì bế đi á, lo vl", 0),
    ("dcm nạp 3 triệu vô app làm nhiệm vụ r nó khóa tk, mất trắng ae ơi", 12),
    ("CA phường gọi, bảo m có lệnh triệu tập liên quan buôn bán chất cấm, ck tiền lo", 0),
    ("ae ơi ai rành cà phê rang xay cho t xin review quán ngon đi", 22),
    ("m ơi cho t mượn sạc iPhone đi, phone t hết pin 5 phần trăm rồi", 22),
    ("dcm bhxh báo nộp 2 củ phí xử lý mới cho rút tiền trợ cấp, c.k vô stk này", 1),
    ("ba gọi video bảo ck 30 triệu lo việc nhà gấp, video rõ mặt luôn", 7),
    ("mãi keo can ph gọi bảo phạt nguội 3 triệu, ck lẹ kẻo bị giữ bằng lái m", 0),
    ("mẹ nhắn tin bảo ck 12 triệu trả nợ ngay, nhưng kiểm tra thì mẹ ko gửi", 7),
    ("BHXH tỉnh thông báo chị có khoản thai sản 18 triệu, nộp phí xác nhận 800k", 1),
    ("dcm bị lừa kiểu việc nhẹ lương cao, nạp 2 triệu phí rồi ko thấy việc đâu", 12),
    ("m mới đọc cuốn sách gì hay hay, recommend cho t đi", 22),
    ("alo em, bưu điện phường giao bưu phẩm đảm bảo, phát sinh phí ký gửi 350k", 17),
    ("tuyển NV part-time nhập data tại nhà, lương 15 triệu/tháng, chỉ cần laptop", 12),
    ("m ơi t check app VCB thấy có giao dịch đúng r đó, ko phải lừa đâu", 22),
    ("hôm nay lương r nè, đi ăn buffet ăn mừng ko m", 22),
    ("ê tk ngân hàng m bị hack r, đọc otp cho t check liền nha ét ô ét", 16),
    ("m ơi bồ t gọi video xin mượn 10 triệu, mặt y chang nhưng giọng hơi lạ", 7),
    ("ae cuối tuần đi câu cá ko, mình biết chỗ hồ câu view đẹp lắm", 22),
    ("trại trẻ mồ côi gặp hỏa hoạn mất hết đồ, ae ck nhanh giúp các em nha", 10),
    ("đầu tư AI trading bot tự động, nạp 5 triệu mỗi tháng nhận 3 triệu lãi", 11),
    ("cơ quan hành chính gửi link cài đặt DVC mới, không cài sẽ mất quyền truy cập", 1),
    ("Tết yêu thương: quỹ tặng 1000 suất cơm cho người vô gia cư, ck ủng hộ", 10),
    ("ae ơi nay có đứa xưng shipper gọi đòi ck 1 triệu cod hàng t ko mua, cẩn thận", 17),
    ("kiểu scam mới: nhắn tin giả khách sạn bảo hoàn cọc, nhập thẻ ngân hàng mất sạch", 22),
    ("m ơi chiều đi uống trà sữa ko, quán gongcha mới mở order đi", 22),
    ("lừa kiểu mới: gọi bảo gói cước điện thoại hết hạn, bấm link gia hạn thì mất tiền", 22),
    ("hôm nay đi siêu thị mua đồ ăn nấu tuần nè bạn, đi cùng ko", 22),
    ("ê ai biết chỗ sửa xe máy uy tín ở Gò Vấp ko, xe t hư bình xăng", 22),
    ("lừa đảo cho vay flash loan, nạp phí 2 triệu để nhận khoản vay 50 triệu ảo", 22),
    ("hàng order từ taobao bị giữ, nộp 800k phí xử lý hải quan qua link web", 17),
    ("ê m ơi t mới nhận offer công ty mới nè, lương tăng 30 phần trăm", 22),
    ("bạn gọi video lúc 2h sáng, khóc lóc bảo bị tai nạn cần 20 triệu gấp", 7),
    ("livestream kêu gọi từ thiện cho dân vùng lũ, scan QR momo đóng góp ngay", 10),
    ("dcm vừa bị lừa kiểu bán acc game, nó nhận tiền xong block t luôn", 22),
    ("dcm ship giao hàng lạ t ko đặt mà nó đòi ck 500k cod, scam chắc", 17),
    ("invest vào dự án bất động sản nghỉ dưỡng, cam kết mua lại 120% sau 12 tháng", 11),
    ("ê bạn có ai quen bán xe cũ ko, t đang tìm xe tay ga", 22),
    ("SOS t mới bị CA gọi xong, bảo ck tiền chạy án 30 củ, help pls!!", 0),
    ("hôm nay đi bầu cử ở phường nè bạn, 7h sáng mở rồi, đi sớm đi", 22),
    ("ê t nghe đâu có kiểu deepfake giả giọng người thân gọi xin tiền á m", 7),
    ("chúc mừng! Bạn là 1 trong 100 KH nhận quà cuối năm từ Vietcombank, bấm link", 13),
    ("ê m bị thằng nào dụ bấm link rồi bay hết tiền trong momo luôn", 22),
    ("shipper bảo m ck trước cod 400k qua momo rồi mới giao, hàng nặng ko vác lên", 17),
    ("ca gọi bảo thẻ ATM t đang bị dùng trái phép, đọc otp đi xác minh", 0),
    ("cháu bé bị bệnh hiểm nghèo cần 500 triệu phẫu thuật, ae ck ủng hộ", 10),
    ("lừa đảo chiếm đoạt: giả admin facebook nhắn tin bảo vi phạm chính sách, phải xác minh", 22),
    ("ê m ơi trúng quay số spin trên shopee dyson airwrap nè, đóng 3 triệu ship", 13),
    ("alo anh ơi em từ VNeID, tài khoản anh bị đánh dấu bất thường, cần xác minh ngay", 1),
    ("trúng giải Samsung Galaxy S25 Ultra, nộp 3 triệu thuế TNCN trước khi nhận máy", 13),
    ("số CMND của anh liên quan vụ án ma túy xuyên quốc gia, phải chuyển tiền bảo lãnh", 0),
    ("ê m ơi t mới chuyển nhà nè, cuối tuần đến tân gia nghen", 22),
    ("m ơi t mới adopt con mèo nè, nó cute phô mai que luôn á", 22),
    ("ê m ơi coi chừng, thằng nào gả CA quận 7 gọi bảo dính án, đòi tiền bảo lãnh", 0),
    ("ê m ơi đừng tin mấy cái quảng cáo vay 0% lãi suất, lừa kiểu mới đó", 22),
    ("ê m ơi tải app v.c.b digibank mới từ link này nha, bản store lỗi r", 16),
    ("đơn hàng shopee bị trả về, ck 80k phí logistics để giao lại lần 2", 17),
    ("ship giao hàng đây ạ, đơn COD 1 triệu 2, anh ra cổng nhận nhé", 17),
    ("hệ thống VNeID gặp sự cố đồng bộ, tải bản patch từ link này để sửa lỗi", 1),
    ("bạn ơi lớp yoga chiều nay có đi ko, mình đợi ở sảnh nhé", 22),
    ("bạn trúng voucher du lịch 20 triệu từ traveloka, ck 1 triệu phí đặt cọc", 13),
    ("hàng ship về r nè m, COD 370k, ra lấy lẹ kẻo ship bỏ đi nha", 17),
    ("đoàn thiện nguyện phát quà trung thu cho trẻ nghèo, ck vào stk cá nhân t nha", 10),
    ("tk bidv m bị locked r, đọc mã otp 6 số cho t reset nha, lẹ lẹ m", 16),
    ("ê bạn cho mình xin số điện thoại thợ sửa máy lạnh nghen", 22),
    ("ae ơi ai rành sửa laptop cho t cái, máy t bị hư màn hình", 22),
    ("Lừa đảo kiểu mới: giả vờ tuyển CTV bán hàng online, thu phí đào tạo 2 triệu", 22),
    ("công an tỉnh gửi lệnh khẩn cấp, tài khoản anh bị nghi rửa tiền, cần phong tỏa", 0),
    ("ê t nhân viên bank nè m ơi, thẻ m bị ai dùng trái phép, ck vô tk này xác minh", 16),
    ("Vietcombank thông báo: tài khoản bị đăng nhập bất thường, bấm link đổi MK ngay", 16),
    ("t vừa nhận tin nhắn bhxh bảo r, nộp 1 triệu là rút 20 triệu trợ cấp nè ae", 1),
    ("Quỹ ABCA kêu gọi ủng hộ 500 phần quà tết, ck vào tk cá nhân chấp nhận momo", 10),
    ("ê m vô group đầu tư coin này đi, admin bảo x10 vốn trong 1 tuần", 11),
    ("ae hảo tâm ck ủng hộ quỹ lũ miền trung nha, mỗi người 1 ít góp sức", 10),
    ("bưu kiện quốc tế của anh bị giữ hải quan, nộp 3 triệu thuế VAT để thông quan", 17),
    ("ê m có đơn hàng COD 500k kìa, ship bảo ck trước kẻo giao cho người khác", 17),
    ("bạn t làm bên bhxh bảo check sổ bảo hiểm qua app fake lun nè, link tao gửi đó", 1),
    ("dcm bị lừa kiểu trúng thưởng shopee, nộp 800k phí ship r ko nhận đc gì ae", 13),
    ("ê m ơi có job đánh giá khách sạn booking 500k/review, vô link đăng ký", 12),
    ("mentor gọi bảo nạp thêm 20 triệu margin call ko thì mất hết vốn", 11),
    ("ae ơi ai quen dentist ngon cho t xin SĐT, t cần nhổ răng khôn", 22),
    ("ê ae ck giúp nha, bé hàng xóm bị tai nạn cần tiền viện phí gấp", 10),
    ("alo giao kiện hàng khẩn, COD 270k, anh ck momo trước nha giao tận tay", 17),
    ("alo em ơi, CA quận Hoàn Kiếm thông báo em bị liên quan tội rửa tiền, giữ bí mật nhé", 0),
    ("BHXH thông báo bạn có khoản thai sản đã duyệt, nhập OTP 6 số để xác nhận nhận tiền", 1),
    ("em là nhân viên BHXH quận 1, sổ anh bị khóa do nợ phí, nộp 3 triệu mở lại", 1),
    ("agribank thông báo thẻ ATM hết hạn, cần xác minh danh tính qua link web", 16),
    ("đặt đơn ảo amazon, deposit 1 triệu, mỗi đơn kiếm 300k, rút sau 3 đơn", 12),
    ("tòa án gửi lệnh triệu tập anh, nếu không ra trình diện sẽ bị dẫn giải", 0),
    ("c.k 500k phí hồ sơ bhxh đi m, mai hết hạn là mất hết quyền lợi bảo hiểm đó", 1),
    ("group Zalo đầu tư vàng online, admin cam kết lãi 5%/ngày, nạp tiền vô app", 11),
    ("OTP 654321 - Giao dịch 15 triệu đang xử lý. Nếu ko phải bạn, bấm link hủy giao dịch", 16),
    ("ae mai đá bóng ko, sân 5 người ở Tân Bình 7h tối nha", 22),
    ("hôm nay teambuilding công ty đi Vũng Tàu, tắm biển xong ăn hải sản", 22),
    ("ê m ơi đơn tiktokshop bị hoàn, ck 200k phí giao lại qua ví momo ship", 17),
    ("t CA gọi nè, m có 24h để ck 50 món ko vô bót ngồi luôn nha", 0)
]

TOTAL = len(scenarios)
print(f"\n📊 Tổng số kịch bản test: {TOTAL}")

if TOTAL != 1000:
    print(f"⚠️ CẢNH BÁO: Số lượng hiện tại là {TOTAL}, kỳ vọng 1000.")

scores = {m: 0 for m in models.keys()}
y_true_all = []
y_pred_all = {m: [] for m in models.keys()}
conf_all = {m: [] for m in models.keys()}

print(f"\n🚀 Đã nạp thành công bộ {TOTAL} test queries cực hạn độ khó. Tiến hành Test...\n")

for i, (text, true_class) in enumerate(scenarios):
    label_str = "HỢP PHÁP (Hard Negative)" if true_class == 22 else f"LỪA ĐẢO LỚP {true_class}"
    print(f"[{i+1}/{TOTAL}] THỰC TẾ: Nhãn {true_class} ({label_str})")
    print(f"   => Text: {text[:80]}...")
    
    y_true_all.append(true_class)
    for v_name, (mtype, model) in models.items():
        try:
            eval_text = text

            if mtype == "tflite":
                pred_class, conf = predict_tflite(model, eval_text)
            else:
                pred_class, conf = predict_hf(model, eval_text)

            # Tính điểm CHÍNH XÁC NHÃN KỊCH BẢN 100%
            if pred_class == true_class:
                scores[v_name] += 1
                status = "✅ Đoán Chính Xác Nhãn"
            else:
                status = f"❌ Đoán Sai (Nhận diện thành {pred_class})"
                
            pred_str = "HỢP PHÁP" if pred_class == 22 else f"LỪA ĐẢO LỚP {pred_class}"
            print(f"    |-- {v_name}: {pred_str} ({conf:5.1f}%) -> {status}")
            
            y_pred_all[v_name].append(pred_class)
            conf_all[v_name].append(conf)
        except Exception as e:
            print(f"    |-- {v_name}: Lỗi TFLite ({str(e)})")
            y_pred_all[v_name].append(-1)
            conf_all[v_name].append(0.0)
    print("-" * 60)

# ============================================================================
# BẢNG XẾP HẠNG TỔNG KẾT
# ============================================================================
print("\n" + "="*80)
print(f" 🛑 KẾT QUẢ ĐÁNH GIÁ {TOTAL} OOD HARD SCENARIOS (Exact Label Matching) ".center(80, " "))
print("="*80)

ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)

for rank, (m_name, score) in enumerate(ranked, 1):
    acc = (score / TOTAL) * 100
    medal = "🥇" if rank==1 else ("🥈" if rank==2 else ("🥉" if rank==3 else "4️⃣"))
    print(f" Hạng {rank}: {m_name.ljust(22)} | Đúng {score}/{TOTAL} ({acc:.1f}%)   {medal}")
print("="*80)

# ============================================================================
# PHÂN TÍCH CHI TIẾT THEO TỪNG LỚP NHÃN
# ============================================================================
print("\n" + "="*80)
print(" 📊 PHÂN TÍCH ĐỘ CHÍNH XÁC THEO TỪNG LỚP NHÃN ".center(80, " "))
print("="*80)

label_names = {
    0:  "Giả danh Công an / Tòa án (AUTH_POLICE_LAWSUIT)",
    1:  "Giả danh VNeID / DVC / BHXH (TAX_GOV_APP)",
    2:  "Dọa khóa SIM viễn thông (TELECOM_LOCK)",
    3:  "Hỗ trợ kỹ thuật giả (TECH_SUPPORT_HIJACK)",
    4:  "Cấp cứu / Viện phí giả (HOSPITAL_EMERGENCY)",
    5:  "Bắt cóc ảo / Tống tiền (VIRTUAL_KIDNAPPING)",
    6:  "Giả danh sếp / Đồng nghiệp (CEO_FRAUD_B2B)",
    7:  "Deepfake người quen mượn tiền (SOCIAL_DEEPFAKE_LOAN)",
    8:  "Lừa tình / Bưu kiện hải quan (ROMANCE_SCAM)",
    9:  "Tống tiền ảnh nhạy cảm (SEXTORTION_BLACKMAIL)",
    10: "Từ thiện ảo / Quyên góp (CHARITY_DONATION)",
    11: "Đầu tư tài chính / Sàn ảo (INVESTMENT_SCAM)",
    12: "Việc nhẹ lương cao / CTV (JOB_TASK_SCAM)",
    13: "Trúng thưởng / Quà tặng (GIFT_LOTTERY)",
    14: "Sôi cầu / Lô đề (GAMBLING_PREDICTION)",
    15: "Visa / Xuất khẩu lao động (IMMIGRATION_VISA_SCAM)",
    16: "Ngân hàng giả mạo / Phishing (BANK_CARD_FRAUD)",
    17: "Shipper giả / Bưu kiện COD (DELIVERY_COD)",
    18: "Trừ tiền dịch vụ tự động (FAKE_SUBSCRIPTION)",
    19: "Tín dụng đen / Đòi nợ (BLACK_CREDIT_TERROR)",
    20: "Dịch vụ lấy lại tiền (RECOVERY_SCAM)",
    21: "Lừa đảo chung (GENERIC_SCAM)",
    22: "An toàn / Hợp lệ (SAFE)"
}

# Đếm số lượng và số đúng của từng model theo từng lớp
label_counts = {}
label_correct = {m: {} for m in models.keys()}

for text, true_class in scenarios:
    label_counts[true_class] = label_counts.get(true_class, 0) + 1

for idx in range(len(y_true_all)):
    t_class = y_true_all[idx]
    for v_name in models.keys():
        p_class = y_pred_all[v_name][idx]
        if t_class not in label_correct[v_name]:
            label_correct[v_name][t_class] = 0
        if p_class == t_class:
            label_correct[v_name][t_class] += 1

for label_id in sorted(label_counts.keys()):
    total_in_label = label_counts[label_id]
    label_display = label_names.get(label_id, f"Lớp {label_id}")
    print(f"\n  🏷️  Nhãn {label_id} — {label_display} ({total_in_label} mẫu):")
    for v_name in models.keys():
        correct = label_correct[v_name].get(label_id, 0)
        acc_label = (correct / total_in_label) * 100 if total_in_label > 0 else 0
        bar = "█" * int(acc_label / 5) + "░" * (20 - int(acc_label / 5))
        print(f"     {v_name.ljust(22)} {bar} {correct}/{total_in_label} ({acc_label:5.1f}%)")

print("\n" + "="*80)
print(" 📈 METRICS: SCAM RECALL, SAFE ACC & FPR (Với Threshold 60%) ".center(80, " "))
print("="*80)

for v_name in models.keys():
    t_list = np.array(y_true_all)
    p_list = np.array(y_pred_all[v_name])
    c_list = np.array(conf_all[v_name])
    
    # Áp dụng threshold 60%
    p_adj = np.copy(p_list)
    p_adj[c_list < 60.0] = 22 # Gán nhãn SAFE nếu threshold < 60%
    
    # Scam Recall (Thực tế là Scam, đoán đúng là Scam - bất kể lớp nào)
    is_scam = t_list != 22
    is_safe = t_list == 22
    
    total_scam = np.sum(is_scam)
    correct_scam = np.sum((p_adj != 22) & is_scam)
    scam_recall = correct_scam / total_scam * 100 if total_scam > 0 else 0
    
    total_safe = np.sum(is_safe)
    correct_safe = np.sum((p_adj == 22) & is_safe)
    safe_acc = correct_safe / total_safe * 100 if total_safe > 0 else 0
    
    # FPR: Thực tế là Safe, nhưng ĐOÁN SAI là Scam
    false_positives = np.sum((p_adj != 22) & is_safe)
    fpr = false_positives / total_safe * 100 if total_safe > 0 else 0
    
    print(f"🔹 {v_name}:")
    print(f"   - Scam Recall: {scam_recall:.1f}% ({correct_scam}/{total_scam})")
    print(f"   - SAFE Acc:    {safe_acc:.1f}% ({correct_safe}/{total_safe})")
    print(f"   - FPR (Lỗi):   {fpr:.1f}% ({false_positives}/{total_safe})")
    
    # Thống kê tác động của threshold
    threshold_impact = np.sum(c_list < 60.0)
    impact_correct = np.sum((c_list < 60.0) & (p_list != 22) & (t_list == 22))
    print(f"   - Bị bẻ lại thành SAFE do Threshold < 60%: {threshold_impact} ca (Cứu đc {impact_correct} nhãn SAFE)\n")

print("="*80)
print(" 🔍 CONFUSION MATRIX (Top-5 Lỗi Phổ Biến) ".center(80, " "))
print("="*80)
try:
    from collections import Counter
    # Lấy model cuối cùng làm focus (thường là Stage 32/33)
    focus_m = list(models.keys())[-1]
    
    t_list = np.array(y_true_all)
    p_adj = np.copy(np.array(y_pred_all[focus_m]))
    c_list = np.array(conf_all[focus_m])
    p_adj[c_list < 60.0] = 22
    
    errors = []
    for i in range(len(t_list)):
        if t_list[i] != p_adj[i]:
            errors.append((t_list[i], p_adj[i]))
            
    err_counts = Counter(errors)
    top_errs = err_counts.most_common(5)
    
    print(f"Top 5 lỗi sai của mô hình {focus_m}:")
    for (t, p), count in top_errs:
        t_name = label_names.get(t, f"Lớp {t}")
        p_name = label_names.get(p, f"Lớp {p}")
        print(f"  - THỰC TẾ {t} ({t_name})  --->  ĐOÁN NHẦM: {p} ({p_name})  [{count} ca]")
except Exception as e:
    print(f"Không thể tạo confusion matrix: {e}")

print("\n" + "="*80)
print("🏁 ĐÁNH GIÁ HOÀN TẤT! Kết quả trên là bộ test TOÀN DIỆN " + str(TOTAL) + " kịch bản.")
print("="*80)
