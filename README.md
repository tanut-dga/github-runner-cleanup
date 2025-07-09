# Docker Cleanup Script สำหรับ GitHub Runner

สคริปต์ bash สำหรับทำความสะอาดพื้นที่ `/var/lib/docker` อย่างปลอดภัยในระบบ GitHub Runner

## คุณสมบัติ

- 🧹 **ทำความสะอาดแบบขั้นตอน**: ลบ containers, images, volumes, networks และ build cache ที่ไม่ใช้
- 🔍 **Dry Run Mode**: ตรวจสอบสิ่งที่จะถูกลบโดยไม่ทำจริง
- 📊 **แสดงผลแบบละเอียด**: แสดงขนาดพื้นที่ก่อนและหลังการทำความสะอาด
- 🔧 **ตั้งค่าอัตโนมัติ**: สร้าง cron job สำหรับการทำความสะอาดอัตโนมัติ
- 📝 **บันทึกการทำงาน**: เก็บ log ไว้ใน `/var/log/docker-cleanup.log`
- 🎨 **แสดงผลสีสัน**: ใช้สีในการแสดงผลเพื่อความชัดเจน

## ความต้องการระบบ

- Ubuntu/Debian Linux
- Docker Engine ติดตั้งแล้ว
- สิทธิ์ root หรือ sudo
- Bash shell

## การติดตั้ง

1. **ดาวน์โหลดสคริปต์**:
   ```bash
   wget -O docker-cleanup.sh https://raw.githubusercontent.com/yourusername/yourrepo/main/docker-cleanup.sh
   chmod +x docker-cleanup.sh
   ```

2. **หรือคัดลอกไฟล์โดยตรง**:
   ```bash
   cp docker-cleanup.sh /usr/local/bin/
   chmod +x /usr/local/bin/docker-cleanup.sh
   ```

## การใช้งาน

### การใช้งานพื้นฐาน
```bash
sudo ./docker-cleanup.sh
```

### ตัวเลือกต่างๆ

| ตัวเลือก | คำอธิบาย |
|---------|----------|
| `--dry-run` | แสดงผลว่าจะทำอะไรโดยไม่ลบข้อมูลจริง |
| `--auto` | รันแบบอัตโนมัติ (เหมาะสำหรับ cron job) |
| `--setup` | ตั้งค่าการทำความสะอาดอัตโนมัติ |
| `--help` | แสดงข้อความช่วยเหลือ |

### ตัวอย่างการใช้งาน

```bash
# ตรวจสอบสิ่งที่จะถูกลบ
sudo ./docker-cleanup.sh --dry-run

# ทำความสะอาดแบบปกติ
sudo ./docker-cleanup.sh

# ตั้งค่าการทำความสะอาดอัตโนมัติ
sudo ./docker-cleanup.sh --setup

# รันแบบอัตโนมัติ (สำหรับ cron)
sudo ./docker-cleanup.sh --auto
```

## ขั้นตอนการทำความสะอาด

สคริปต์จะทำความสะอาดตามขั้นตอนดังนี้:

1. **ตรวจสอบระบบ**: ตรวจสอบสิทธิ์และสถานะ Docker
2. **แสดงข้อมูลปัจจุบัน**: แสดงขนาดและจำนวนทรัพยากร Docker
3. **หยุด containers**: หยุด containers ที่ไม่ทำงาน
4. **ลบ containers**: ลบ containers ที่หยุดทำงานแล้ว
5. **ลบ images**: ลบ images ที่ไม่มี containers ใช้
6. **ลบ volumes**: ลบ volumes ที่ไม่ใช้
7. **ลบ networks**: ลบ networks ที่ไม่ใช้
8. **ลบ build cache**: ลบ build cache ที่เก็บไว้
9. **ทำความสะอาดแบบลึก** (ถ้าเลือก): ลบทุกอย่างที่ไม่ใช้รวมถึง images ที่ไม่มี tag

## การตั้งค่าอัตโนมัติ

สคริปต์สามารถตั้งค่าให้ทำงานอัตโนมัติผ่าน cron job:

```bash
sudo ./docker-cleanup.sh --setup
```

จะสร้าง cron job ที่ทำงานทุกวันเวลา 02:00 น.

หรือตั้งค่าเองผ่าน crontab:
```bash
sudo crontab -e
```

เพิ่มบรรทัด:
```
0 2 * * * /usr/local/bin/docker-cleanup.sh --auto
```

## ไฟล์ Log

การทำงานทั้งหมดจะถูกบันทึกไว้ใน:
```
/var/log/docker-cleanup.log
```

## การกำหนดค่า

สามารถแก้ไขตัวแปรเหล่านี้ในสคริปต์:

```bash
LOG_FILE="/var/log/docker-cleanup.log"      # ตำแหน่งไฟล์ log
MIN_FREE_SPACE_GB=5                         # พื้นที่ว่างขั้นต่ำ (GB)
DRY_RUN=false                              # โหมด dry run
```

## ข้อควรระวัง

⚠️ **คำเตือน**: 
- สคริปต์นี้จะลบข้อมูล Docker ที่ไม่ใช้ ควรสำรองข้อมูลสำคัญก่อน
- ในโหมด "ทำความสะอาดแบบลึก" จะลบ images ทั้งหมดที่ไม่ใช้
- ควรใช้ `--dry-run` เพื่อตรวจสอบก่อนการลบจริง

## การแก้ไขปัญหา

### Docker service ไม่ทำงาน
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### ไม่มีสิทธิ์เข้าถึง
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Log file ไม่สามารถเขียนได้
```bash
sudo touch /var/log/docker-cleanup.log
sudo chmod 644 /var/log/docker-cleanup.log
```

## ตัวอย่างผลลัพธ์

```
[INFO] เริ่มต้นการทำความสะอาด Docker ณ 2024-01-15 14:30:00
[INFO] พื้นที่ว่างปัจจุบัน: 15GB
[INFO] === ขนาดปัจจุบันของ Docker ===
[INFO] กำลังหยุด containers ที่ไม่จำเป็น...
[SUCCESS] หยุด containers ที่ไม่ทำงานแล้ว
[INFO] === เริ่มทำความสะอาด Docker ===
[INFO] ขั้นตอนที่ 1: ลบ containers ที่หยุดทำงาน
[INFO] ขั้นตอนที่ 2: ลบ images ที่ไม่มี containers ใช้
[SUCCESS] การทำความสะอาดเสร็จสิ้น ณ 2024-01-15 14:35:00
```

## การสนับสนุน

หากพบปัญหาหรือต้องการความช่วยเหลือ:

1. ตรวจสอบ log file: `/var/log/docker-cleanup.log`
2. ใช้ `--dry-run` เพื่อดูผลลัพธ์ก่อนลบจริง
3. ตรวจสอบสิทธิ์การเข้าถึง Docker

## License

MIT License - ใช้งานได้อย่างอิสระ

## การพัฒนา

สคริปต์นี้พัฒนาสำหรับใช้งานใน GitHub Runner environment และสามารถปรับแต่งได้ตามความต้องการ
