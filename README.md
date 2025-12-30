# Gemini CLI Config Installer (Gemini 3 Focus)

สคริปต์ไฟล์เดียวสำหรับติดตั้ง:
- `~/.gemini/GEMINI.md` (policy เน้น Gemini 3)
- `~/.gemini/settings.json` (MCP servers + model overrides ตามที่กำหนด)

ระหว่างติดตั้ง ผู้ใช้จะต้องกรอก API Keys เองทุกขั้นตอน (ไม่ฝัง secrets ลงใน repo)

---

## What You Get

เมื่อติดตั้งเสร็จ สคริปต์จะ:
1) สร้างโฟลเดอร์ `~/.gemini/` (ถ้ายังไม่มี)
2) สำรองไฟล์เดิม (ถ้ามี) ด้วย `.bak.<timestamp>`
3) ขอให้ผู้ใช้กรอก API keys แบบซ่อนตัวอักษร:
   - `EXA_API_KEY`
   - `CONTEXT7_API_KEY`
   - `BRAVE_API_KEY`
4) Export keys ให้ใช้ได้ทันทีใน session ปัจจุบัน และ “เลือกได้” ว่าจะ persist ลงไฟล์ rc (เช่น `.bashrc`) หรือไม่
5) เขียนไฟล์ `GEMINI.md` และ `settings.json` ตามที่ตั้งค่าไว้

---

## Requirements

### Required
- `bash` (หรือ shell ที่รัน bash ได้)
- คำสั่งพื้นฐาน: `mkdir`, `cp`, `cat`, `date`

### Recommended (สำหรับ MCP servers)
- Node.js + `npx` (เพราะ MCP servers ใน `settings.json` ถูกเรียกผ่าน `npx`)
- Gemini CLI (ติดตั้งและล็อกอินเรียบร้อย)

> หมายเหตุ: คุณสามารถติดตั้ง config ได้แม้ไม่มี Node/npx แต่ MCP servers จะใช้งานไม่ได้จนกว่าจะติดตั้ง Node/npx

---

## Repository Structure (แนะนำ)
ตัวอย่างโครงสร้าง:
