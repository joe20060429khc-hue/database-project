const express = require('express');
const sql = require('mssql');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// ==========================================
// 1. SQL Server 連線設定 (請根據你的 SSMS 環境修改)
// ==========================================
const dbConfig = {
    user: 'sa',                  
    password: '1234',             // 填入你幫 sa 設定的密碼
    server: '127.0.0.1',         // 用本機標準 IP
    database: '123',             // 你的資料庫名稱
    port: 1433,                  // 💡 剛剛手動固定的標準 Port！
    options: {
        encrypt: false,           
        trustServerCertificate: true
    }
};
// 連線到資料庫（加強偵錯版）
async function startServer() {
    try {
        console.log('⏳ 正在嘗試連線至 SQL Server...');
        await sql.connect(dbConfig);
        console.log('✅ 成功連線至 SQL Server 資料庫！');
        
        // 成功連線後才啟動 Web 伺服器
        const PORT = 3000;
        app.listen(PORT, () => {
            console.log(`🚀 伺服器正在 http://localhost:${PORT} 運行中！`);
        });
    } catch (err) {
        console.error('❌❌❌ 資料庫連線慘遭失敗！錯誤詳細原因如下：');
        console.error(err); // 這裡會強迫 Windows 吐出真實病因
    }
}

startServer();
// ==========================================
// 2. API 功能路由 (包含白板要求的三大核心語法)
// ==========================================

// 功能 [一]：學生登入驗證
app.post('/api/login', async (req, res) => {
    const { student_number, password } = req.body;
    try {
        const result = await sql.query`
            SELECT student_id, student_name, class_id 
            FROM students 
            WHERE student_number = ${student_number} AND password_hash = ${password}
        `;
        if (result.recordset.length > 0) {
            res.json({ success: true, student: result.recordset[0] });
        } else {
            res.json({ success: false, message: '學號或密碼錯誤' });
        }
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 功能 [二]：個人課表查詢 (多表 JOIN 範例)
app.get('/api/schedule/:studentId', async (req, res) => {
    try {
        const result = await sql.query`
            SELECT sch.weekday AS 星期, sch.start_time AS 開始時間, sch.end_time AS 結束時間, 
                   co.course_name AS 課程名稱, sch.classroom AS 教室
            FROM students st
            JOIN schedules sch ON st.class_id = sch.class_id
            JOIN courses co ON sch.course_id = co.course_id
            WHERE st.student_id = ${req.params.studentId}
            ORDER BY sch.weekday, sch.start_time
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 功能 [三]：個人作業狀態統計 (JOIN + Aggregate 聚合函數範例)
app.get('/api/stats/:studentId', async (req, res) => {
    try {
        const result = await sql.query`
            SELECT 
                COUNT(a.assignment_id) AS 總應繳作業數,
                SUM(CASE WHEN sub.submission_status = N'已繳交' THEN 1 ELSE 0 END) AS 已完成數,
                SUM(CASE WHEN sub.submission_status = N'遲交' THEN 1 ELSE 0 END) AS 遲交數,
                SUM(CASE WHEN sub.submission_status = N'未繳交' OR sub.submission_status IS NULL THEN 1 ELSE 0 END) AS 待完成數
            FROM students st
            LEFT JOIN schedules s ON st.class_id = s.class_id
            LEFT JOIN assignments a ON s.schedule_id = a.schedule_id
            LEFT JOIN assignment_submissions sub ON a.assignment_id = sub.assignment_id AND st.student_id = sub.student_id
            WHERE st.student_id = ${req.params.studentId}
            GROUP BY st.student_name
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 功能 [四]：個人成績與全班平均對比 (大魔王：JOIN + 相關子查詢 Subquery + AVG 統計)
app.get('/api/grades/:studentId', async (req, res) => {
    try {
        const result = await sql.query`
            SELECT 
                co.course_name AS 課程,
                a.title AS 作業名稱,
                ISNULL(CAST(sub.grade AS VARCHAR), '尚未評分') AS 我的分數,
                (
                    SELECT ROUND(AVG(sub2.grade), 2) 
                    FROM assignment_submissions sub2 
                    WHERE sub2.assignment_id = a.assignment_id
                ) AS 全班平均分數
            FROM students st
            JOIN schedules s ON st.class_id = s.class_id
            JOIN courses co ON s.course_id = co.course_id
            JOIN assignments a ON s.schedule_id = a.schedule_id
            LEFT JOIN assignment_submissions sub ON a.assignment_id = sub.assignment_id AND st.student_id = sub.student_id
            WHERE st.student_id = ${req.params.studentId}
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 功能 [五]：同班同學作業進度邊緣人名單 (進階：Subquery + NOT IN 排除法)
// 找出同班級裡面，還有哪些人「完全沒有繳交」某個作業，可以用來做同儕督促系統
app.get('/api/slackers/:classId', async (req, res) => {
    try {
        const result = await sql.query`
            SELECT st.student_number AS 學號, st.student_name AS 姓名, a.title AS 缺交作業
            FROM students st
            CROSS JOIN assignments a  -- 產生該班級應有的作業矩陣
            JOIN schedules s ON a.schedule_id = s.schedule_id AND s.class_id = st.class_id
            WHERE st.class_id = ${req.params.classId}
            AND st.student_id NOT IN (
                SELECT sub.student_id 
                FROM assignment_submissions sub 
                WHERE sub.assignment_id = a.assignment_id AND sub.submission_status IN (N'已繳交', N'遲交')
            )
            ORDER BY a.title;
        `;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});
