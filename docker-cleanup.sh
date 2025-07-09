#!/bin/bash

# GitHub Runner Docker Cleanup Script
# วันที่: $(date +%Y-%m-%d)
# จุดประสงค์: คืนพื้นที่ /var/lib/docker อย่างปลอดภัยสำหรับ GitHub Runner

set -euo pipefail

# สีสำหรับการแสดงผล
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ตัวแปรสำหรับการกำหนดค่า
LOG_FILE="/var/log/docker-cleanup.log"
MIN_FREE_SPACE_GB=5
DRY_RUN=false

# ฟังก์ชันสำหรับการแสดงผล
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# ฟังก์ชันตรวจสอบสิทธิ์
check_permissions() {
    if [[ $EUID -ne 0 ]]; then
        print_error "สคริปต์นี้ต้องรันด้วยสิทธิ์ root"
        exit 1
    fi
}

# ฟังก์ชันตรวจสอบ Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker ไม่ได้ติดตั้งในระบบ"
        exit 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        print_warning "Docker service ไม่ทำงาน กำลังเริ่มต้น..."
        systemctl start docker
    fi
}

# ฟังก์ชันตรวจสอบพื้นที่ดิสก์
check_disk_space() {
    local available_space=$(df /var/lib/docker | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    print_info "พื้นที่ว่างปัจจุบัน: ${available_gb}GB"
    
    if [[ $available_gb -lt $MIN_FREE_SPACE_GB ]]; then
        print_warning "พื้นที่ว่างน้อยกว่า ${MIN_FREE_SPACE_GB}GB"
        return 1
    fi
    return 0
}

# ฟังก์ชันแสดงขนาดก่อนทำความสะอาด
show_current_usage() {
    print_info "=== ขนาดปัจจุบันของ Docker ==="
    
    echo "Docker system usage:"
    docker system df
    
    echo -e "\nขนาดรายละเอียด:"
    du -sh /var/lib/docker 2>/dev/null || echo "ไม่สามารถเข้าถึง /var/lib/docker"
    
    echo -e "\nจำนวน containers:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"
    
    echo -e "\nจำนวน images:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    
    echo -e "\nจำนวน volumes:"
    docker volume ls
}

# ฟังก์ชันหยุด containers ที่ไม่จำเป็น
stop_unnecessary_containers() {
    print_info "กำลังหยุด containers ที่ไม่จำเป็น..."
    
    # หยุด containers ที่หยุดทำงานแล้วหรือ exited
    local stopped_containers=$(docker ps -a -q -f status=exited)
    if [[ -n "$stopped_containers" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "[DRY RUN] จะหยุด containers: $stopped_containers"
        else
            docker rm $stopped_containers
            print_success "หยุด containers ที่ไม่ทำงานแล้ว"
        fi
    else
        print_info "ไม่มี containers ที่ต้องหยุด"
    fi
}

# ฟังก์ชันทำความสะอาด Docker แบบขั้นตอน
cleanup_docker_step_by_step() {
    print_info "=== เริ่มทำความสะอาด Docker ==="
    
    # ขั้นตอนที่ 1: ลบ containers ที่หยุดทำงาน
    print_info "ขั้นตอนที่ 1: ลบ containers ที่หยุดทำงาน"
    if [[ "$DRY_RUN" == "true" ]]; then
        docker container prune --dry-run
    else
        docker container prune -f
    fi
    
    # ขั้นตอนที่ 2: ลบ images ที่ไม่ใช้
    print_info "ขั้นตอนที่ 2: ลบ images ที่ไม่มี containers ใช้"
    if [[ "$DRY_RUN" == "true" ]]; then
        docker image prune --dry-run
    else
        docker image prune -f
    fi
    
    # ขั้นตอนที่ 3: ลบ volumes ที่ไม่ใช้
    print_info "ขั้นตอนที่ 3: ลบ volumes ที่ไม่ใช้"
    if [[ "$DRY_RUN" == "true" ]]; then
        docker volume prune --dry-run
    else
        docker volume prune -f
    fi
    
    # ขั้นตอนที่ 4: ลบ networks ที่ไม่ใช้
    print_info "ขั้นตอนที่ 4: ลบ networks ที่ไม่ใช้"
    if [[ "$DRY_RUN" == "true" ]]; then
        docker network prune --dry-run
    else
        docker network prune -f
    fi
    
    # ขั้นตอนที่ 5: ลบ build cache
    print_info "ขั้นตอนที่ 5: ลบ build cache"
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY RUN] จะลบ build cache"
    else
        docker builder prune -f
    fi
}

# ฟังก์ชันทำความสะอาดแบบสุดท้าย (ใช้เมื่อจำเป็น)
deep_cleanup() {
    print_warning "=== ทำความสะอาดแบบลึก (ใช้เมื่อจำเป็นเท่านั้น) ==="
    
    read -p "คุณแน่ใจที่จะทำความสะอาดแบบลึก? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "กำลังทำความสะอาดแบบลึก..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            docker system prune -a --dry-run
        else
            docker system prune -a -f --volumes
        fi
        
        print_success "ทำความสะอาดแบบลึกเสร็จสิ้น"
    else
        print_info "ยกเลิกการทำความสะอาดแบบลึก"
    fi
}

# ฟังก์ชันแสดงผลหลังทำความสะอาด
show_cleanup_results() {
    print_info "=== ผลลัพธ์หลังทำความสะอาด ==="
    
    echo "Docker system usage หลังทำความสะอาด:"
    docker system df
    
    echo -e "\nขนาดของ /var/lib/docker:"
    du -sh /var/lib/docker 2>/dev/null || echo "ไม่สามารถเข้าถึง /var/lib/docker"
    
    echo -e "\nพื้นที่ว่างในระบบ:"
    df -h /var/lib/docker
}

# ฟังก์ชันสำหรับการตั้งค่าอัตโนมัติ
setup_automated_cleanup() {
    print_info "=== ตั้งค่าการทำความสะอาดอัตโนมัติ ==="
    
    # สร้าง cron job
    local cron_job="0 2 * * * /usr/local/bin/docker-cleanup.sh --auto"
    
    read -p "ต้องการตั้งค่าให้ทำความสะอาดอัตโนมัติทุกวันเวลา 02:00? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # คัดลอกสคริปต์ไปยัง /usr/local/bin
        cp "$0" /usr/local/bin/docker-cleanup.sh
        chmod +x /usr/local/bin/docker-cleanup.sh
        
        # เพิ่ม cron job
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        
        print_success "ตั้งค่าการทำความสะอาดอัตโนมัติเสร็จสิ้น"
    fi
}

# ฟังก์ชันหลักสำหรับ cleanup
main_cleanup() {
    print_info "เริ่มต้นการทำความสะอาด Docker ณ $(date)"
    
    # ตรวจสอบสิทธิ์และ Docker
    check_permissions
    check_docker
    
    # แสดงขนาดปัจจุบัน
    show_current_usage
    
    # หยุด containers ที่ไม่จำเป็น
    stop_unnecessary_containers
    
    # ทำความสะอาดแบบขั้นตอน
    cleanup_docker_step_by_step
    
    # ถามว่าต้องการทำความสะอาดแบบลึกหรือไม่
    if [[ "$1" != "--auto" ]]; then
        deep_cleanup
    fi
    
    # แสดงผลลัพธ์
    show_cleanup_results
    
    print_success "การทำความสะอาดเสร็จสิ้น ณ $(date)"
}

# ฟังก์ชันแสดงการใช้งาน
usage() {
    echo "การใช้งาน: $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "  --dry-run    แสดงผลว่าจะทำอะไรโดยไม่ทำจริง"
    echo "  --auto       รันแบบอัตโนมัติ (สำหรับ cron job)"
    echo "  --setup      ตั้งค่าการทำความสะอาดอัตโนมัติ"
    echo "  --help       แสดงข้อความช่วยเหลือนี้"
}

# เริ่มต้นการทำงาน
main() {
    # สร้าง log file
    touch "$LOG_FILE"
    
    case "${1:-}" in
        --dry-run)
            DRY_RUN=true
            main_cleanup
            ;;
        --auto)
            main_cleanup --auto
            ;;
        --setup)
            setup_automated_cleanup
            ;;
        --help)
            usage
            ;;
        *)
            main_cleanup
            ;;
    esac
}

# เรียกใช้ฟังก์ชันหลัก
main "$@"
