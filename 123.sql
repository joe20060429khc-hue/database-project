-- =========================================================================
-- 1. 清除舊有資料表 (嚴格遵循相反順序，避免外鍵約束報錯)
-- =========================================================================
DROP TABLE IF EXISTS assignment_submissions;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS schedules;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS courses;
DROP TABLE IF EXISTS classes;
GO

-- =========================================================================
-- 2. 建表 (SQL Server 語法)
-- =========================================================================

-- 班級表
CREATE TABLE classes (
    class_id INT IDENTITY(1,1) PRIMARY KEY,
    class_name NVARCHAR(50) NOT NULL UNIQUE
);

-- 學生表
CREATE TABLE students (
    student_id INT IDENTITY(1,1) PRIMARY KEY,
    student_number VARCHAR(10) NOT NULL UNIQUE, -- 學號由你手動指定
    student_name NVARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    class_id INT NOT NULL,
    FOREIGN KEY (class_id) REFERENCES classes(class_id) ON DELETE NO ACTION
);

-- 課程表
CREATE TABLE courses (
    course_id INT IDENTITY(1,1) PRIMARY KEY,
    course_name NVARCHAR(100) NOT NULL,
    credits INT NOT NULL DEFAULT 3
);

-- 課表
CREATE TABLE schedules (
    schedule_id INT IDENTITY(1,1) PRIMARY KEY,
    class_id INT NOT NULL,
    course_id INT NOT NULL,
    weekday INT NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    classroom NVARCHAR(50),
    FOREIGN KEY (class_id) REFERENCES classes(class_id) ON DELETE CASCADE,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE,
    CONSTRAINT chk_weekday CHECK (weekday BETWEEN 1 AND 7),
    CONSTRAINT unique_class_schedule UNIQUE (class_id, weekday, start_time)
);

-- 作業表
CREATE TABLE assignments (
    assignment_id INT IDENTITY(1,1) PRIMARY KEY,
    schedule_id INT NOT NULL,
    title NVARCHAR(150) NOT NULL,
    description NVARCHAR(MAX),
    due_date DATETIME NOT NULL,
    FOREIGN KEY (schedule_id) REFERENCES schedules(schedule_id) ON DELETE CASCADE
);

-- 作業繳交表
CREATE TABLE assignment_submissions (
    submission_id INT IDENTITY(1,1) PRIMARY KEY,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    submission_status NVARCHAR(20) DEFAULT N'未繳交',
    file_path NVARCHAR(255),
    submitted_at DATETIME,
    grade DECIMAL(5,2) DEFAULT NULL,
    teacher_feedback NVARCHAR(MAX),
    FOREIGN KEY (assignment_id) REFERENCES assignments(assignment_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE NO ACTION,
    CONSTRAINT unique_student_assignment UNIQUE (student_id, assignment_id),
    CONSTRAINT chk_status CHECK (submission_status IN (N'未繳交', N'已繳交', N'遲交'))
);
GO

-- 測試資料（手動指定學號）
INSERT INTO classes (class_name) VALUES (N'A班'), (N'B班');

INSERT INTO courses (course_name, credits) VALUES 
(N'資料結構', 3),
(N'線性代數', 3),
(N'作業系統', 3),
(N'資料庫系統', 3);

INSERT INTO students (student_number, student_name, email, password_hash, class_id) VALUES
('1130001', N'張小明', 'ming@school.edu', '123', 1),
('1130002', N'李美玲', 'ling@school.edu', '123', 1),
('1130003', N'陳大華', 'hua@school.edu', '123', 1),
('1130004', N'林志強', 'qiang@school.edu', '123', 1),
('1130005', N'黃雅婷', 'ting@school.edu', '123', 1),
('1130006', N'曾冠宇', 'yu@school.edu', '123', 1),
('1130007', N'吳自立', 'li@school.edu', '123', 1),
('1130008', N'蔡依婷', 'yiting@school.edu', '123', 1),
('1130009', N'洪嘉玲', 'ling2@school.edu', '123', 1),
('1130010', N'郭建成', 'cheng@school.edu', '123', 1),
('1130011', N'王大同', 'tong@school.edu', '123', 2),
('1130012', N'蔡淑芬', 'fen@school.edu', '123', 2),
('1130013', N'吳俊傑', 'jie@school.edu', '123', 2),
('1130014', N'許美惠', 'hui@school.edu', '123', 2),
('1130015', N'鄭信宏', 'hong@school.edu', '123', 2),
('1130016', N'謝佳穎', 'ying@school.edu', '123', 2),
('1130017', N'賴建國', 'guo@school.edu', '123', 2),
('1130018', N'邱淑貞', 'zhen@school.edu', '123', 2),
('1130019', N'楊冠宏', 'yang@school.edu', '123', 2),
('1130020', N'周杰倫', 'jay@school.edu', '123', 2);

-- 寫入排班課表 (A、B 兩班時間與教室完全錯開)
-- A班：週一/週二早上
-- B班：週二/週三下午與早上
INSERT INTO schedules (class_id, course_id, weekday, start_time, end_time, classroom) VALUES 
-- A班課表
(1, 1, 1, '09:00:00', '12:00:00', N'1館 101'), -- 週一早上 資料結構
(1, 2, 2, '09:00:00', '12:00:00', N'1館 202'), -- 週二早上 線性代數
(1, 3, 4, '09:00:00', '12:00:00', N'1館 204'), -- 週四早上 作業系統

-- B班課表
(2, 1, 3, '09:00:00', '12:00:00', N'1館 101'), -- 週三早上 資料結構
(2, 2, 2, '14:00:00', '17:00:00', N'1館 202'), -- 週二下午 線性代數
(2, 4, 5, '14:00:00', '17:00:00', N'1館 105'); -- 週五下午 資料庫系統

-- 寫入作業 (作業關聯至特定班級的排班)
INSERT INTO assignments (schedule_id, title, description, due_date) VALUES 
(1, N'A班-資料結構作業：Linked List', N'請用 C++ 實作指標鏈結', '2026-07-10 23:59:59'),
(2, N'A班-線性代數：特徵值計算', N'課本習題 4.2', '2026-07-12 23:59:59'),
(3, N'A班-作業系統：Process 模擬', N'實作 CPU 排程演算法', '2026-07-15 23:59:59'),
(4, N'B班-資料結構作業：Tree 走訪', N'請用 Java 實作 BST 走訪', '2026-07-11 23:59:59'),
(5, N'B班-線性代數：矩陣運算', N'課本習題 1.5', '2026-07-13 23:59:59'),
(6, N'B班-資料庫作業：ERD 繪製', N'繪製圖書管理系統 ERD', '2026-07-18 23:59:59');

