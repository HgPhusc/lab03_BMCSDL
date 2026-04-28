-- ============================================================
-- BÀI THỰC HÀNH SỐ 3
-- Script 3: Kiểm tra và dữ liệu mẫu
-- ============================================================


USE QLSVNhom;
GO

-- ============================================================
-- TEST: Thêm nhân viên bằng SP_INS_PUBLIC_NHANVIEN
-- ============================================================
PRINT N'=== TEST: Thêm nhân viên ===';

EXEC SP_INS_PUBLIC_NHANVIEN 'NV01', N'Nguyễn Văn A', 'NVA@gmail.com', 3000000, 'NVA', 'abcd12';
EXEC SP_INS_PUBLIC_NHANVIEN 'NV02', N'Trần Thị B', 'TTB@gmail.com', 5000000, 'TTB', 'xyz789';
EXEC SP_INS_PUBLIC_NHANVIEN 'NV03', N'Lê Văn C', 'LVC@gmail.com', 4500000, 'LVC', 'pass123';
GO

-- Kiểm tra dữ liệu nhân viên (LUONG đã mã hóa)
SELECT MANV, HOTEN, EMAIL, TENDN, PUBKEY,
       CONVERT(VARCHAR(MAX), MATKHAU, 2) AS MATKHAU_HEX,
       DATALENGTH(LUONG) AS LUONG_ENCRYPTED_BYTES
FROM NHANVIEN;
GO


-- ============================================================
-- TEST: Truy vấn nhân viên và giải mã lương
-- ============================================================
PRINT N'=== TEST: Giải mã lương nhân viên ===';

EXEC SP_SEL_PUBLIC_NHANVIEN 'NVA', 'abcd12';
EXEC SP_SEL_PUBLIC_NHANVIEN 'TTB', 'xyz789';
GO


-- ============================================================
-- THÊM DỮ LIỆU MẪU: LOP
-- ============================================================
INSERT INTO LOP (MALOP, TENLOP, MANV) VALUES
    ('L001', N'Lớp Công nghệ thông tin 1', 'NV01'),
    ('L002', N'Lớp Công nghệ thông tin 2', 'NV02'),
    ('L003', N'Lớp Hệ thống thông tin', 'NV01');
GO

-- ============================================================
-- THÊM DỮ LIỆU MẪU: SINHVIEN
-- ============================================================
EXEC SP_INS_SINHVIEN 'SV001', N'Phạm Văn Đức', '2003-01-15', N'Hà Nội', 'L001', 'phamvanduc', 'sv001pass';
EXEC SP_INS_SINHVIEN 'SV002', N'Nguyễn Thị Hoa', '2003-05-20', N'TP.HCM', 'L001', 'nguyenthihoa', 'sv002pass';
EXEC SP_INS_SINHVIEN 'SV003', N'Trần Minh Khoa', '2002-09-10', N'Đà Nẵng', 'L002', 'tranminhkhoa', 'sv003pass';
EXEC SP_INS_SINHVIEN 'SV004', N'Lê Thị Lan', '2003-03-08', N'Cần Thơ', 'L002', 'lethilan', 'sv004pass';
EXEC SP_INS_SINHVIEN 'SV005', N'Hoàng Văn Nam', '2002-12-25', N'Huế', 'L003', 'hoangvannam', 'sv005pass';
GO

-- ============================================================
-- TEST: Nhập bảng điểm (mã hóa bằng Public Key NV01)
-- ============================================================
PRINT N'=== TEST: Nhập điểm (mã hóa bằng Public Key) ===';

EXEC SP_INS_BANGDIEM 'SV001', 'HP001', 8.5, 'NV01';
EXEC SP_INS_BANGDIEM 'SV001', 'HP002', 7.0, 'NV01';
EXEC SP_INS_BANGDIEM 'SV002', 'HP001', 9.0, 'NV01';
EXEC SP_INS_BANGDIEM 'SV002', 'HP003', 6.5, 'NV01';
GO

-- Xem bảng điểm đã mã hóa
SELECT bd.MASV, bd.MAHP, DATALENGTH(bd.DIEMTHI) AS DIEMTHI_BYTES
FROM BANGDIEM bd;
GO

-- ============================================================
-- TEST: Xem bảng điểm (giải mã)
-- ============================================================
PRINT N'=== TEST: Giải mã bảng điểm ===';

EXEC SP_SEL_BANGDIEM 'SV001', 'NV01', 'abcd12';
EXEC SP_SEL_BANGDIEM 'SV002', 'NV01', 'abcd12';
GO

-- ============================================================
-- TEST: Kiểm tra Asymmetric Keys đã tạo
-- ============================================================
PRINT N'=== Danh sách Asymmetric Keys ===';
SELECT name, asymmetric_key_id, algorithm_desc, key_length
FROM sys.asymmetric_keys;
GO

PRINT N'✔ Tất cả tests hoàn thành!';
GO
