-- ============================================================
-- BÀI THỰC HÀNH SỐ 3 - Mã hóa dữ liệu với RSA (Public Key)
-- Script 2: Tạo Master Key, Stored Procedures mã hóa RSA
-- ============================================================

USE QLSVNhom;
GO

-- ============================================================
-- TẠO DATABASE MASTER KEY (bắt buộc trước khi tạo asymmetric key)
-- ============================================================
IF NOT EXISTS (
    SELECT * FROM sys.symmetric_keys 
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'MasterKey@2024!';
    PRINT N'✔ Tạo Database Master Key thành công!';
END
ELSE
BEGIN
    PRINT N'ℹ Database Master Key đã tồn tại.';
END
GO

-- ============================================================
-- STORED PROCEDURE: SP_INS_PUBLIC_NHANVIEN
-- Thêm nhân viên mới với:
--   - MATKHAU mã hóa SHA1
--   - LUONG mã hóa bằng RSA_512 (Asymmetric Key)
--   - PUBKEY = MANV (tên khóa công khai)
-- ============================================================
IF OBJECT_ID('SP_INS_PUBLIC_NHANVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_INS_PUBLIC_NHANVIEN;
GO

CREATE PROCEDURE SP_INS_PUBLIC_NHANVIEN
    @MANV       VARCHAR(20),
    @HOTEN      NVARCHAR(100),
    @EMAIL      VARCHAR(100),
    @LUONGCB    BIGINT,
    @TENDN      NVARCHAR(100),
    @MK         NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL        NVARCHAR(MAX);
    DECLARE @KeyName    VARCHAR(20) = @MANV;   -- Tên khóa = MANV
    DECLARE @KeyExists  INT = 0;

    -- Kiểm tra nhân viên đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM NHANVIEN WHERE MANV = @MANV)
    BEGIN
        RAISERROR(N'Nhân viên với MANV = %s đã tồn tại!', 16, 1, @MANV);
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM NHANVIEN WHERE TENDN = @TENDN)
    BEGIN
        RAISERROR(N'Tên đăng nhập %s đã được sử dụng!', 16, 1, @TENDN);
        RETURN;
    END

    -- Kiểm tra Asymmetric Key đã tồn tại chưa
    IF EXISTS (SELECT * FROM sys.asymmetric_keys WHERE name = @KeyName)
    BEGIN
        SET @KeyExists = 1;
    END

    -- Tạo Asymmetric Key (RSA_512) nếu chưa có
    -- Tên key = MANV, bảo vệ bằng PASSWORD = @MK
    IF @KeyExists = 0
    BEGIN
        SET @SQL = N'CREATE ASYMMETRIC KEY ' + QUOTENAME(@KeyName) + 
                   N' WITH ALGORITHM = RSA_512 ENCRYPTION BY PASSWORD = ' + 
                   QUOTENAME(@MK, '''') + N';';
        EXEC sp_executesql @SQL;
    END

    -- Mã hóa LUONG bằng Public Key của Asymmetric Key
    DECLARE @LuongBinary    VARBINARY(MAX);
    DECLARE @LuongText      NVARCHAR(50) = CAST(@LUONGCB AS NVARCHAR(50));

    SET @SQL = N'SELECT @Result = EncryptByAsymKey(AsymKey_ID(' + 
               QUOTENAME(@KeyName, '''') + N'), CAST(' +
               QUOTENAME(@LuongText, '''') + N' AS VARBINARY(MAX)));';

    EXEC sp_executesql @SQL, N'@Result VARBINARY(MAX) OUTPUT', @Result = @LuongBinary OUTPUT;

    -- Thêm nhân viên vào bảng
    INSERT INTO NHANVIEN (MANV, HOTEN, EMAIL, LUONG, TENDN, MATKHAU, PUBKEY)
    VALUES (
        @MANV,
        @HOTEN,
        @EMAIL,
        @LuongBinary,
        @TENDN,
        HASHBYTES('SHA1', @MK),    -- Mã hóa MATKHAU bằng SHA1
        @KeyName                    -- PUBKEY = MANV
    );

    PRINT N'✔ Thêm nhân viên ' + @HOTEN + N' thành công!';
END
GO

-- ============================================================
-- STORED PROCEDURE: SP_SEL_PUBLIC_NHANVIEN
-- Truy vấn thông tin nhân viên và giải mã LUONG
-- ============================================================
IF OBJECT_ID('SP_SEL_PUBLIC_NHANVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_PUBLIC_NHANVIEN;
GO

CREATE PROCEDURE SP_SEL_PUBLIC_NHANVIEN
    @TENDN      NVARCHAR(100),
    @MK         NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL        NVARCHAR(MAX);
    DECLARE @MANV       VARCHAR(20);
    DECLARE @PUBKEY     VARCHAR(20);

    -- Xác thực tài khoản (TENDN + SHA1(MK))
    SELECT @MANV = MANV, @PUBKEY = PUBKEY
    FROM NHANVIEN
    WHERE TENDN = @TENDN
      AND MATKHAU = HASHBYTES('SHA1', @MK);

    IF @MANV IS NULL
    BEGIN
        RAISERROR(N'Tên đăng nhập hoặc mật khẩu không đúng!', 16, 1);
        RETURN;
    END

    -- Truy vấn và giải mã lương sử dụng Private Key (bảo vệ bằng @MK)
    -- DecryptByAsymKey cần password để mở khóa Private Key
    SET @SQL = N'
    SELECT 
        nv.MANV,
        nv.HOTEN,
        nv.EMAIL,
        CAST(
            DecryptByAsymKey(
                AsymKey_ID(' + QUOTENAME(@PUBKEY, '''') + N'),
                nv.LUONG,
                CAST(' + QUOTENAME(@MK, '''') + N' AS NVARCHAR(128))
            ) AS NVARCHAR(50)
        ) AS LUONGCB
    FROM NHANVIEN nv
    WHERE nv.MANV = ' + QUOTENAME(@MANV, '''') + N';';

    EXEC sp_executesql @SQL;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_LOGIN_NHANVIEN
-- Đăng nhập nhân viên (trả về thông tin nếu hợp lệ)
-- ============================================================
IF OBJECT_ID('SP_LOGIN_NHANVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_LOGIN_NHANVIEN;
GO

CREATE PROCEDURE SP_LOGIN_NHANVIEN
    @MANV       VARCHAR(20),
    @MK         NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT MANV, HOTEN, EMAIL, TENDN, PUBKEY
    FROM NHANVIEN
    WHERE MANV = @MANV
      AND MATKHAU = HASHBYTES('SHA1', @MK);
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_SEL_LOP_BY_MANV
-- Lấy danh sách lớp mà nhân viên đó quản lý
-- ============================================================
IF OBJECT_ID('SP_SEL_LOP_BY_MANV', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_LOP_BY_MANV;
GO

CREATE PROCEDURE SP_SEL_LOP_BY_MANV
    @MANV VARCHAR(20)
AS
BEGIN
    SELECT l.MALOP, l.TENLOP, l.MANV, nv.HOTEN AS HOTEN_GVCN
    FROM LOP l
    LEFT JOIN NHANVIEN nv ON l.MANV = nv.MANV
    WHERE l.MANV = @MANV;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_SEL_ALL_LOP
-- Lấy toàn bộ danh sách lớp
-- ============================================================
IF OBJECT_ID('SP_SEL_ALL_LOP', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_ALL_LOP;
GO

CREATE PROCEDURE SP_SEL_ALL_LOP
AS
BEGIN
    SELECT l.MALOP, l.TENLOP, l.MANV, nv.HOTEN AS HOTEN_GVCN
    FROM LOP l
    LEFT JOIN NHANVIEN nv ON l.MANV = nv.MANV;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_INS_LOP
-- Thêm lớp mới
-- ============================================================
IF OBJECT_ID('SP_INS_LOP', 'P') IS NOT NULL DROP PROCEDURE SP_INS_LOP;
GO
CREATE PROCEDURE SP_INS_LOP
    @MALOP  VARCHAR(20),
    @TENLOP NVARCHAR(100),
    @MANV   VARCHAR(20)
AS
BEGIN
    INSERT INTO LOP (MALOP, TENLOP, MANV) VALUES (@MALOP, @TENLOP, @MANV);
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_UPD_LOP
-- Cập nhật thông tin lớp
-- ============================================================
IF OBJECT_ID('SP_UPD_LOP', 'P') IS NOT NULL DROP PROCEDURE SP_UPD_LOP;
GO
CREATE PROCEDURE SP_UPD_LOP
    @MALOP  VARCHAR(20),
    @TENLOP NVARCHAR(100),
    @MANV   VARCHAR(20)
AS
BEGIN
    UPDATE LOP SET TENLOP = @TENLOP, MANV = @MANV WHERE MALOP = @MALOP;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_DEL_LOP
-- Xóa lớp
-- ============================================================
IF OBJECT_ID('SP_DEL_LOP', 'P') IS NOT NULL DROP PROCEDURE SP_DEL_LOP;
GO
CREATE PROCEDURE SP_DEL_LOP
    @MALOP VARCHAR(20)
AS
BEGIN
    DELETE FROM LOP WHERE MALOP = @MALOP;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_SEL_SV_BY_LOP
-- Lấy sinh viên theo lớp
-- ============================================================
IF OBJECT_ID('SP_SEL_SV_BY_LOP', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_SV_BY_LOP;
GO
CREATE PROCEDURE SP_SEL_SV_BY_LOP
    @MALOP NVARCHAR(200)
AS
BEGIN
    SELECT MASV, HOTEN, NGAYSINH, DIACHI, MALOP, TENDN
    FROM SINHVIEN
    WHERE MALOP = @MALOP;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_INS_SINHVIEN
-- Thêm sinh viên mới (MATKHAU mã hóa SHA1)
-- ============================================================
IF OBJECT_ID('SP_INS_SINHVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_INS_SINHVIEN;
GO
CREATE PROCEDURE SP_INS_SINHVIEN
    @MASV       NVARCHAR(20),
    @HOTEN      NVARCHAR(100),
    @NGAYSINH   DATETIME,
    @DIACHI     NVARCHAR(200),
    @MALOP      NVARCHAR(200),
    @TENDN      NVARCHAR(100),
    @MATKHAU    NVARCHAR(100)
AS
BEGIN
    INSERT INTO SINHVIEN (MASV, HOTEN, NGAYSINH, DIACHI, MALOP, TENDN, MATKHAU)
    VALUES (@MASV, @HOTEN, @NGAYSINH, @DIACHI, @MALOP, @TENDN,
            HASHBYTES('SHA1', @MATKHAU));
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_UPD_SINHVIEN
-- Cập nhật sinh viên (chỉ nhân viên quản lý lớp đó mới được sửa)
-- ============================================================
IF OBJECT_ID('SP_UPD_SINHVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_UPD_SINHVIEN;
GO
CREATE PROCEDURE SP_UPD_SINHVIEN
    @MASV       NVARCHAR(20),
    @HOTEN      NVARCHAR(100),
    @NGAYSINH   DATETIME,
    @DIACHI     NVARCHAR(200),
    @MALOP      NVARCHAR(200),
    @TENDN      NVARCHAR(100),
    @MANV_LOGIN VARCHAR(20)   -- Nhân viên đang đăng nhập
AS
BEGIN
    -- Kiểm tra nhân viên có quyền sửa sinh viên thuộc lớp đó không
    IF NOT EXISTS (
        SELECT 1 FROM LOP 
        WHERE MALOP = @MALOP AND MANV = @MANV_LOGIN
    )
    BEGIN
        RAISERROR(N'Bạn không có quyền chỉnh sửa sinh viên thuộc lớp này!', 16, 1);
        RETURN;
    END

    UPDATE SINHVIEN
    SET HOTEN = @HOTEN, NGAYSINH = @NGAYSINH,
        DIACHI = @DIACHI, MALOP = @MALOP, TENDN = @TENDN
    WHERE MASV = @MASV;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_DEL_SINHVIEN
-- Xóa sinh viên (chỉ nhân viên quản lý lớp đó mới được xóa)
-- ============================================================
IF OBJECT_ID('SP_DEL_SINHVIEN', 'P') IS NOT NULL
    DROP PROCEDURE SP_DEL_SINHVIEN;
GO
CREATE PROCEDURE SP_DEL_SINHVIEN
    @MASV       NVARCHAR(20),
    @MANV_LOGIN VARCHAR(20)
AS
BEGIN
    DECLARE @MALOP NVARCHAR(200);
    SELECT @MALOP = MALOP FROM SINHVIEN WHERE MASV = @MASV;

    IF NOT EXISTS (
        SELECT 1 FROM LOP WHERE MALOP = @MALOP AND MANV = @MANV_LOGIN
    )
    BEGIN
        RAISERROR(N'Bạn không có quyền xóa sinh viên thuộc lớp này!', 16, 1);
        RETURN;
    END

    DELETE FROM BANGDIEM WHERE MASV = @MASV;
    DELETE FROM SINHVIEN WHERE MASV = @MASV;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_INS_BANGDIEM
-- Nhập điểm thi, mã hóa DIEMTHI bằng Public Key của nhân viên đăng nhập
-- ============================================================
IF OBJECT_ID('SP_INS_BANGDIEM', 'P') IS NOT NULL
    DROP PROCEDURE SP_INS_BANGDIEM;
GO
CREATE PROCEDURE SP_INS_BANGDIEM
    @MASV       VARCHAR(20),
    @MAHP       VARCHAR(20),
    @DIEMTHI    DECIMAL(5,2),
    @PUBKEY_NV  VARCHAR(20)    -- Tên Public Key của nhân viên đang đăng nhập
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL            NVARCHAR(MAX);
    DECLARE @DiemEncrypted  VARBINARY(MAX);
    DECLARE @DiemStr        NVARCHAR(20) = CAST(@DIEMTHI AS NVARCHAR(20));

    -- Mã hóa điểm bằng Public Key của nhân viên
    SET @SQL = N'SELECT @Result = EncryptByAsymKey(AsymKey_ID(' + 
               QUOTENAME(@PUBKEY_NV, '''') + N'), 
               CAST(' + QUOTENAME(@DiemStr, '''') + N' AS VARBINARY(MAX)));';

    EXEC sp_executesql @SQL, N'@Result VARBINARY(MAX) OUTPUT', @Result = @DiemEncrypted OUTPUT;

    -- Thêm hoặc cập nhật bảng điểm
    IF EXISTS (SELECT 1 FROM BANGDIEM WHERE MASV = @MASV AND MAHP = @MAHP)
        UPDATE BANGDIEM SET DIEMTHI = @DiemEncrypted
        WHERE MASV = @MASV AND MAHP = @MAHP;
    ELSE
        INSERT INTO BANGDIEM (MASV, MAHP, DIEMTHI) VALUES (@MASV, @MAHP, @DiemEncrypted);
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_SEL_BANGDIEM
-- Xem bảng điểm (giải mã bằng Private Key của nhân viên)
-- ============================================================
IF OBJECT_ID('SP_SEL_BANGDIEM', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_BANGDIEM;
GO
CREATE PROCEDURE SP_SEL_BANGDIEM
    @MASV       VARCHAR(20),
    @PUBKEY_NV  VARCHAR(20),
    @MK         NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
    SELECT 
        bd.MASV,
        sv.HOTEN AS HOTEN_SV,
        bd.MAHP,
        hp.TENHP,
        CAST(
            DecryptByAsymKey(
                AsymKey_ID(' + QUOTENAME(@PUBKEY_NV, '''') + N'),
                bd.DIEMTHI,
                CAST(' + QUOTENAME(@MK, '''') + N' AS NVARCHAR(128))
            ) AS NVARCHAR(20)
        ) AS DIEMTHI
    FROM BANGDIEM bd
    JOIN SINHVIEN sv ON bd.MASV = sv.MASV
    JOIN HOCPHAN hp ON bd.MAHP = hp.MAHP
    WHERE bd.MASV = ' + QUOTENAME(@MASV, '''') + N';';

    EXEC sp_executesql @SQL;
END
GO


-- ============================================================
-- STORED PROCEDURE: SP_SEL_ALL_HOCPHAN
-- Lấy danh sách học phần
-- ============================================================
IF OBJECT_ID('SP_SEL_ALL_HOCPHAN', 'P') IS NOT NULL
    DROP PROCEDURE SP_SEL_ALL_HOCPHAN;
GO
CREATE PROCEDURE SP_SEL_ALL_HOCPHAN
AS
BEGIN
    SELECT MAHP, TENHP, SOTC FROM HOCPHAN;
END
GO


-- ============================================================
-- DỮ LIỆU MẪU - HOCPHAN
-- ============================================================
INSERT INTO HOCPHAN (MAHP, TENHP, SOTC) VALUES
    ('HP001', N'Cơ sở dữ liệu', 3),
    ('HP002', N'Lập trình Java', 3),
    ('HP003', N'Mạng máy tính', 2),
    ('HP004', N'An toàn thông tin', 3),
    ('HP005', N'Trí tuệ nhân tạo', 3);
GO


PRINT N'✔ Tạo tất cả Stored Procedures thành công!';
GO