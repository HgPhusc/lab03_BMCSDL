# BÀI THỰC HÀNH SỐ 3 — Mã hóa dữ liệu RSA (Public Key)
> Khoa CNTT · ĐH Khoa học Tự nhiên TP.HCM

---

## 📁 Cấu trúc project

```
project/
├── sql/
│   ├── 01_create_database.sql      ← Tạo DB & bảng
│   ├── 02_stored_procedures.sql    ← Master Key + Stored Procedures
│   └── 03_test_data.sql            ← Dữ liệu mẫu & test
└── python_app/
    ├── app.py                      ← Flask app chính
    ├── requirements.txt
    └── templates/
        ├── base.html
        ├── login.html
        ├── dashboard.html
        ├── lop.html
        ├── sinhvien.html
        ├── bangdiem.html
        └── nhanvien.html
```

---

## 🗄️ BƯỚC 1: Cài đặt SQL Server

### Chạy SQL scripts theo thứ tự:

1. **`01_create_database.sql`** — Tạo DB `QLSVNhom` và các bảng
2. **`02_stored_procedures.sql`** — Tạo Master Key + tất cả Stored Procedures
3. **`03_test_data.sql`** — Chèn dữ liệu mẫu và test

```sql
-- Chạy trên SQL Server Management Studio (SSMS)
-- Mở từng file và nhấn F5
```

> ⚠️ **Lưu ý quan trọng**: Script dùng `CREATE MASTER KEY` — bắt buộc phải có trước khi tạo Asymmetric Key.

---

## 🐍 BƯỚC 2: Cấu hình Python App

### 2.1. Cài đặt Python dependencies

```bash
cd python_app
pip install -r requirements.txt
```

### 2.2. Cài ODBC Driver for SQL Server

- **Windows**: Tải từ https://aka.ms/downloadmsodbcsql
- **Linux/Mac**: Xem hướng dẫn tại https://docs.microsoft.com/sql/connect/odbc

### 2.3. Chỉnh sửa cấu hình kết nối trong `app.py`

```python
DB_CONFIG = {
    'server':   'localhost',        # ← Tên SQL Server của bạn
    'database': 'QLSVNhom',
    'username': 'sa',               # ← Tài khoản SQL Server
    'password': 'YourPassword123!', # ← Mật khẩu của bạn
    'driver':   '{ODBC Driver 17 for SQL Server}'
}
```

### 2.4. Chạy ứng dụng

```bash
python app.py
```

Truy cập: **http://localhost:5000**

---

## 🔐 Tài khoản mẫu (sau khi chạy `03_test_data.sql`)

| Mã NV | Mật khẩu | Họ tên       |
|-------|----------|--------------|
| NV01  | abcd12   | Nguyễn Văn A |
| NV02  | xyz789   | Trần Thị B   |
| NV03  | pass123  | Lê Văn C     |

---

## 📋 Các Stored Procedures

| Tên SP | Mô tả |
|--------|-------|
| `SP_INS_PUBLIC_NHANVIEN` | Thêm NV — MATKHAU hash SHA1, LUONG mã hóa RSA-512 |
| `SP_SEL_PUBLIC_NHANVIEN` | Xem thông tin NV + giải mã LUONG |
| `SP_LOGIN_NHANVIEN` | Xác thực đăng nhập |
| `SP_SEL_ALL_LOP` | Danh sách lớp |
| `SP_SEL_LOP_BY_MANV` | Lớp do NV quản lý |
| `SP_INS_LOP` / `SP_UPD_LOP` / `SP_DEL_LOP` | CRUD lớp |
| `SP_SEL_SV_BY_LOP` | SV theo lớp |
| `SP_INS_SINHVIEN` / `SP_UPD_SINHVIEN` / `SP_DEL_SINHVIEN` | CRUD SV (có kiểm tra quyền) |
| `SP_INS_BANGDIEM` | Nhập điểm (mã hóa bằng Public Key NV) |
| `SP_SEL_BANGDIEM` | Xem điểm (giải mã bằng Private Key) |
| `SP_SEL_ALL_HOCPHAN` | Danh sách học phần |

---

## 🔒 Cơ chế mã hóa

### Mật khẩu (SHA1 — hash một chiều)
```sql
HASHBYTES('SHA1', @MK)
```

### Lương & Điểm (RSA-512 — Asymmetric Key)
```sql
-- Tạo khóa (1 khóa/nhân viên, tên key = MANV)
CREATE ASYMMETRIC KEY [NV01] 
  WITH ALGORITHM = RSA_512 
  ENCRYPTION BY PASSWORD = 'abcd12';

-- Mã hóa bằng Public Key
EncryptByAsymKey(AsymKey_ID('NV01'), CAST(@LUONG AS VARBINARY(MAX)))

-- Giải mã bằng Private Key (cần password)
DecryptByAsymKey(AsymKey_ID('NV01'), @LuongEncrypted, 'abcd12')
```

---

## 📊 Yêu cầu e) — SQL Profiler

Để theo dõi thao tác nhập điểm bằng SQL Profiler:

1. Mở **SQL Server Management Studio**
2. Vào **Tools → SQL Server Profiler**
3. Kết nối đến server, tạo Trace mới
4. Filter **DatabaseName = QLSVNhom**
5. Chọn events: `SQL:BatchStarting`, `RPC:Completed`, `SP:StmtCompleted`
6. Thực hiện nhập điểm trên web app
7. Quan sát: câu lệnh gọi `SP_INS_BANGDIEM` → `EncryptByAsymKey(...)` → INSERT vào BANGDIEM

**Nhận xét**: Trong SQL Profiler sẽ thấy rằng dữ liệu điểm thi KHÔNG bao giờ xuất hiện ở dạng plaintext trong network traffic — chỉ thấy các giá trị VARBINARY đã mã hóa, đảm bảo bảo mật dữ liệu điểm thi.
