"""
Bài Thực Hành Số 3 - Quản Lý Sinh Viên
Ứng dụng Flask + SQL Server
"""

from flask import Flask, render_template, request, redirect, url_for, session, jsonify, flash
import pyodbc
import os

app = Flask(__name__)
app.secret_key = 'QLSVNhom_SecretKey_2024'

# ============================================================
# CẤU HÌNH KẾT NỐI SQL SERVER
# Chỉnh sửa thông tin kết nối cho phù hợp
# ============================================================
DB_CONFIG = {
    'server':   'localhost',        # hoặc tên server SQL Server của bạn
    'database': 'QLSVNhom',
    'username': 'sa',               # tài khoản SQL Server
    'password': '123456', # mật khẩu SQL Server
    'driver':   '{ODBC Driver 17 for SQL Server}'
}

def get_connection():
    """Tạo kết nối đến SQL Server"""
    conn_str = (
        f"DRIVER={DB_CONFIG['driver']};"
        f"SERVER={DB_CONFIG['server']};"
        f"DATABASE={DB_CONFIG['database']};"
        f"UID={DB_CONFIG['username']};"
        f"PWD={DB_CONFIG['password']};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str)


def execute_sp(sp_name, params=None):
    """Thực thi Stored Procedure, trả về list of dicts"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if params:
            placeholders = ', '.join(['?' for _ in params])
            cursor.execute(f"EXEC {sp_name} {placeholders}", params)
        else:
            cursor.execute(f"EXEC {sp_name}")

        # Đọc kết quả nếu có
        try:
            columns = [col[0] for col in cursor.description]
            rows = cursor.fetchall()
            conn.commit()
            return [dict(zip(columns, row)) for row in rows]
        except TypeError:
            conn.commit()
            return []
    except pyodbc.Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


def execute_sp_no_result(sp_name, params=None):
    """Thực thi SP không cần kết quả trả về"""
    conn = get_connection()
    cursor = conn.cursor()
    try:
        if params:
            placeholders = ', '.join(['?' for _ in params])
            cursor.execute(f"EXEC {sp_name} {placeholders}", params)
        else:
            cursor.execute(f"EXEC {sp_name}")
        conn.commit()
        return True
    except pyodbc.Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()
        conn.close()


# ============================================================
# ROUTES
# ============================================================

@app.route('/')
def index():
    if 'manv' not in session:
        return redirect(url_for('login'))
    return redirect(url_for('dashboard'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        manv = request.form.get('manv', '').strip().upper()
        mk   = request.form.get('matkhau', '').strip()

        if not manv or not mk:
            return render_template('login.html', error='Vui lòng nhập đầy đủ thông tin!')

        try:
            result = execute_sp('SP_LOGIN_NHANVIEN', [manv, mk])
            if result:
                nv = result[0]
                session['manv']   = nv['MANV']
                session['hoten']  = nv['HOTEN']
                session['tendn']  = nv['TENDN']
                session['pubkey'] = nv['PUBKEY']
                session['mk']     = mk   # Lưu MK để giải mã lương/điểm
                return redirect(url_for('dashboard'))
            else:
                return render_template('login.html', error='Mã nhân viên hoặc mật khẩu không đúng!')
        except Exception as e:
            return render_template('login.html', error=f'Lỗi kết nối: {str(e)}')

    return render_template('login.html')


@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))


@app.route('/dashboard')
def dashboard():
    if 'manv' not in session:
        return redirect(url_for('login'))
    return render_template('dashboard.html')


# ============================================================
# QUẢN LÝ LỚP HỌC
# ============================================================

@app.route('/lop')
def lop_list():
    if 'manv' not in session:
        return redirect(url_for('login'))
    try:
        lop_list = execute_sp('SP_SEL_ALL_LOP')
        return render_template('lop.html', lop_list=lop_list)
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
        return render_template('lop.html', lop_list=[])


@app.route('/lop/them', methods=['POST'])
def lop_them():
    if 'manv' not in session:
        return redirect(url_for('login'))
    malop  = request.form.get('malop', '').strip().upper()
    tenlop = request.form.get('tenlop', '').strip()
    manv   = request.form.get('manv', '').strip().upper()
    try:
        execute_sp_no_result('SP_INS_LOP', [malop, tenlop, manv])
        flash('Thêm lớp thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('lop_list'))


@app.route('/lop/sua', methods=['POST'])
def lop_sua():
    if 'manv' not in session:
        return redirect(url_for('login'))
    malop  = request.form.get('malop', '').strip().upper()
    tenlop = request.form.get('tenlop', '').strip()
    manv   = request.form.get('manv', '').strip().upper()
    try:
        execute_sp_no_result('SP_UPD_LOP', [malop, tenlop, manv])
        flash('Cập nhật lớp thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('lop_list'))


@app.route('/lop/xoa', methods=['POST'])
def lop_xoa():
    if 'manv' not in session:
        return redirect(url_for('login'))
    malop = request.form.get('malop', '').strip().upper()
    try:
        execute_sp_no_result('SP_DEL_LOP', [malop])
        flash('Xóa lớp thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('lop_list'))


# ============================================================
# QUẢN LÝ SINH VIÊN
# ============================================================

@app.route('/sinhvien')
def sv_list():
    if 'manv' not in session:
        return redirect(url_for('login'))
    malop = request.args.get('malop', '')
    try:
        # Lấy danh sách lớp mà NV quản lý
        lop_quan_ly = execute_sp('SP_SEL_LOP_BY_MANV', [session['manv']])
        sv_list = []
        if malop:
            sv_list = execute_sp('SP_SEL_SV_BY_LOP', [malop])
        return render_template('sinhvien.html',
                               lop_quan_ly=lop_quan_ly,
                               sv_list=sv_list,
                               malop_selected=malop)
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
        return render_template('sinhvien.html', lop_quan_ly=[], sv_list=[], malop_selected='')


@app.route('/sinhvien/them', methods=['POST'])
def sv_them():
    if 'manv' not in session:
        return redirect(url_for('login'))
    masv     = request.form.get('masv', '').strip().upper()
    hoten    = request.form.get('hoten', '').strip()
    ngaySinh = request.form.get('ngaysinh', None)
    diachi   = request.form.get('diachi', '').strip()
    malop    = request.form.get('malop', '').strip().upper()
    tendn    = request.form.get('tendn', '').strip()
    matkhau  = request.form.get('matkhau', '').strip()

    # Kiểm tra NV có quản lý lớp này không
    lop_quan_ly = execute_sp('SP_SEL_LOP_BY_MANV', [session['manv']])
    malop_ids = [l['MALOP'] for l in lop_quan_ly]
    if malop not in malop_ids:
        flash('Bạn không có quyền thêm sinh viên vào lớp này!', 'error')
        return redirect(url_for('sv_list', malop=malop))

    try:
        execute_sp_no_result('SP_INS_SINHVIEN', [masv, hoten, ngaySinh, diachi, malop, tendn, matkhau])
        flash('Thêm sinh viên thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('sv_list', malop=malop))


@app.route('/sinhvien/sua', methods=['POST'])
def sv_sua():
    if 'manv' not in session:
        return redirect(url_for('login'))
    masv     = request.form.get('masv', '').strip().upper()
    hoten    = request.form.get('hoten', '').strip()
    ngaySinh = request.form.get('ngaysinh', None)
    diachi   = request.form.get('diachi', '').strip()
    malop    = request.form.get('malop', '').strip().upper()
    tendn    = request.form.get('tendn', '').strip()
    try:
        execute_sp_no_result('SP_UPD_SINHVIEN',
                             [masv, hoten, ngaySinh, diachi, malop, tendn, session['manv']])
        flash('Cập nhật sinh viên thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('sv_list', malop=malop))


@app.route('/sinhvien/xoa', methods=['POST'])
def sv_xoa():
    if 'manv' not in session:
        return redirect(url_for('login'))
    masv  = request.form.get('masv', '').strip().upper()
    malop = request.form.get('malop', '').strip().upper()
    try:
        execute_sp_no_result('SP_DEL_SINHVIEN', [masv, session['manv']])
        flash('Xóa sinh viên thành công!', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('sv_list', malop=malop))


# ============================================================
# QUẢN LÝ BẢNG ĐIỂM
# ============================================================

@app.route('/bangdiem')
def bangdiem():
    if 'manv' not in session:
        return redirect(url_for('login'))
    masv = request.args.get('masv', '')
    try:
        lop_quan_ly = execute_sp('SP_SEL_LOP_BY_MANV', [session['manv']])
        hocphan_list = execute_sp('SP_SEL_ALL_HOCPHAN')
        sv_list = []
        for lop in lop_quan_ly:
            sv_lop = execute_sp('SP_SEL_SV_BY_LOP', [lop['MALOP']])
            sv_list.extend(sv_lop)

        diem_list = []
        if masv:
            diem_list = execute_sp('SP_SEL_BANGDIEM',
                                   [masv, session['pubkey'], session['mk']])

        return render_template('bangdiem.html',
                               sv_list=sv_list,
                               hocphan_list=hocphan_list,
                               diem_list=diem_list,
                               masv_selected=masv)
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
        return render_template('bangdiem.html',
                               sv_list=[], hocphan_list=[], diem_list=[], masv_selected='')


@app.route('/bangdiem/nhap', methods=['POST'])
def bangdiem_nhap():
    if 'manv' not in session:
        return redirect(url_for('login'))
    masv    = request.form.get('masv', '').strip().upper()
    mahp    = request.form.get('mahp', '').strip().upper()
    diem    = request.form.get('diemthi', '0').strip()
    try:
        execute_sp_no_result('SP_INS_BANGDIEM',
                             [masv, mahp, float(diem), session['pubkey']])
        flash('Nhập điểm thành công! Điểm được mã hóa bằng Public Key.', 'success')
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
    return redirect(url_for('bangdiem', masv=masv))


# ============================================================
# QUẢN LÝ NHÂN VIÊN (xem thông tin lương đã giải mã)
# ============================================================

@app.route('/nhanvien')
def nhanvien():
    if 'manv' not in session:
        return redirect(url_for('login'))
    try:
        result = execute_sp('SP_SEL_PUBLIC_NHANVIEN',
                            [session['tendn'], session['mk']])
        return render_template('nhanvien.html', nhanvien=result[0] if result else None)
    except Exception as e:
        flash(f'Lỗi: {str(e)}', 'error')
        return render_template('nhanvien.html', nhanvien=None)


# ============================================================
# MAIN
# ============================================================
if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
