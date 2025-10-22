#!/bin/bash
##############################################################################
# SİSTEM KİLİDİNİ VE YOUTUBE ENGELİNİ KALDIR
# Tüm koruma mekanizmalarını devre dışı bırakır
##############################################################################

set -e

# Root kontrolü
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Bu script root yetkisi gerektirir!"
    echo "Kullanım: sudo bash $0"
    exit 1
fi

# Renk kodları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "=========================================="
echo "  🔓 SİSTEM KİLİDİ KALDIRMA ARACI"
echo "=========================================="
echo ""

# Onay iste
read -p "Tüm güvenlik önlemlerini kaldırmak istediğinizden emin misiniz? (evet/hayır): " confirm

if [ "$confirm" != "evet" ]; then
    log_warning "İşlem iptal edildi"
    exit 0
fi

echo ""
log_info "Sistem kilidi kaldırılıyor..."
echo ""

##############################################################################
# 1. .DESKTOP DOSYALARINI GERİ YÜKLE
##############################################################################
log_info ".desktop dosyaları geri yükleniyor..."

if [ -d /root/desktop-backups ]; then
    # Yedekleri geri yükle
    for backup_file in /root/desktop-backups/*.backup; do
        if [ -f "$backup_file" ]; then
            original_name=$(basename "$backup_file" .backup)
            original_path="/usr/share/applications/$original_name"
            
            cp "$backup_file" "$original_path"
            log_success "Geri yüklendi: $original_name"
        fi
    done
    
    log_success "Tüm .desktop dosyaları geri yüklendi"
else
    log_warning "Yedek dizini bulunamadı: /root/desktop-backups"
fi

##############################################################################
# 2. ÇÖP KUTUSU WRAPPER'LARINI KALDIR
##############################################################################
log_info "Çöp kutusu korumaları kaldırılıyor..."

TRASH_WRAPPERS=("nautilus-wrapper" "nemo-wrapper" "thunar-wrapper" "pcmanfm-wrapper" "dolphin-wrapper" "caja-wrapper")

for wrapper in "${TRASH_WRAPPERS[@]}"; do
    if [ -f "/usr/local/bin/$wrapper" ]; then
        rm -f "/usr/local/bin/$wrapper"
        log_success "Kaldırıldı: $wrapper"
    fi
done

##############################################################################
# 3. IPTABLES KURALLARINI TEMİZLE
##############################################################################
log_info "iptables kuralları temizleniyor..."

# Dosyaları unlock et
chattr -i /etc/iptables/rules.v4 2>/dev/null || true
chattr -i /etc/iptables/rules.v6 2>/dev/null || true
chattr -i /etc/hosts 2>/dev/null || true

# YouTube ile ilgili tüm kuralları kaldır
iptables -F OUTPUT 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true
ip6tables -F OUTPUT 2>/dev/null || true
ip6tables -F FORWARD 2>/dev/null || true

log_success "iptables kuralları temizlendi"

##############################################################################
# 4. /ETC/HOSTS DOSYASINI TEMİZLE
##############################################################################
log_info "/etc/hosts dosyası temizleniyor..."

# YouTube girişlerini sil
sed -i '/youtube/Id' /etc/hosts
sed -i '/youtu/Id' /etc/hosts

log_success "/etc/hosts temizlendi"

##############################################################################
# 5. NETWORKMANAGER'I GERİ YÜKLE
##############################################################################
log_info "NetworkManager geri yükleniyor..."

# WiFi kısıtlamalarını kaldır
rm -f /etc/NetworkManager/conf.d/99-no-wifi-control.conf 2>/dev/null || true
rm -f /etc/NetworkManager/conf.d/99-block-wifi.conf 2>/dev/null || true

# NetworkManager'ı yeniden başlat
systemctl restart NetworkManager 2>/dev/null || true

log_success "WiFi yönetimi geri yüklendi"

##############################################################################
# 6. WPA_SUPPLICANT'I AKTİFLEŞTİR
##############################################################################
log_info "wpa_supplicant aktifleştiriliyor..."

systemctl enable wpa_supplicant 2>/dev/null || true
systemctl start wpa_supplicant 2>/dev/null || true

log_success "wpa_supplicant aktif"

##############################################################################
# 7. BLUETOOTH'U AKTİFLEŞTİR
##############################################################################
log_info "Bluetooth aktifleştiriliyor..."

systemctl enable bluetooth 2>/dev/null || true
systemctl start bluetooth 2>/dev/null || true

log_success "Bluetooth aktif"

##############################################################################
# 8. USB STORAGE'I GERİ YÜKLE
##############################################################################
log_info "USB storage geri yükleniyor..."

rm -f /etc/modprobe.d/block-usb-storage.conf 2>/dev/null || true

# USB storage modülünü yükle
modprobe usb-storage 2>/dev/null || true

log_success "USB storage aktif"

##############################################################################
# 9. SİSTEM SERVİSLERİNİ DURDUR
##############################################################################
log_info "Sistem servisleri durduruluyor..."

# YouTube block servisini durdur ve devre dışı bırak
systemctl stop youtube-block.service 2>/dev/null || true
systemctl disable youtube-block.service 2>/dev/null || true
rm -f /etc/systemd/system/youtube-block.service 2>/dev/null || true

# System lock servisini durdur ve devre dışı bırak
systemctl stop system-lock.service 2>/dev/null || true
systemctl disable system-lock.service 2>/dev/null || true
rm -f /etc/systemd/system/system-lock.service 2>/dev/null || true

# Systemd'yi yenile
systemctl daemon-reload

log_success "Sistem servisleri durduruldu"

##############################################################################
# 10. SCRİPT DOSYALARINI KALDIR (OPSİYONEL)
##############################################################################
log_info "Script dosyaları kontrol ediliyor..."

read -p "Script dosyalarını da silmek istiyor musunuz? (evet/hayır): " remove_scripts

if [ "$remove_scripts" == "evet" ]; then
    rm -f /usr/local/bin/app-locker.py 2>/dev/null || true
    rm -f /usr/local/bin/block-youtube.sh 2>/dev/null || true
    rm -f /usr/local/bin/system-unlock.sh 2>/dev/null || true
    
    log_success "Script dosyaları kaldırıldı"
else
    log_info "Script dosyaları korundu"
fi

##############################################################################
# 11. IPTABLES KURALLARI KALİCİ OLARAK TEMİZLE
##############################################################################
log_info "iptables kuralları kalıcı olarak temizleniyor..."

if command -v iptables-save &> /dev/null; then
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
    log_success "iptables kuralları kalıcı olarak temizlendi"
fi

##############################################################################
# 12. GRUB AYARLARINI GERİ AL (OPSİYONEL)
##############################################################################
log_info "GRUB ayarları kontrol ediliyor..."

if [ -f /etc/default/grub ]; then
    if grep -q "GRUB_DISABLE_OS_PROBER=true" /etc/default/grub; then
        sed -i '/GRUB_DISABLE_OS_PROBER=true/d' /etc/default/grub
        update-grub 2>/dev/null || true
        log_success "GRUB ayarları geri alındı"
    fi
fi

##############################################################################
# 13. SİSTEM GÜVENLİK AYARLARINI GERI AL
##############################################################################
log_info "Sistem güvenlik ayarları geri alınıyor..."

# IP forwarding'i geri aç (gerekirse)
echo 1 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true

log_success "Sistem ayarları geri alındı"

##############################################################################
# 14. YEDEK DİZİNİNİ TEMİZLE (OPSİYONEL)
##############################################################################
log_info "Yedek dosyaları kontrol ediliyor..."

read -p "Yedek dosyalarını da silmek istiyor musunuz? (evet/hayır): " remove_backups

if [ "$remove_backups" == "evet" ]; then
    rm -rf /root/desktop-backups 2>/dev/null || true
    log_success "Yedek dosyaları silindi"
else
    log_info "Yedek dosyaları korundu (/root/desktop-backups)"
fi

##############################################################################
# 15. ÖZET VE BİLGİLENDİRME
##############################################################################
echo ""
echo "=========================================="
echo "  ✅ SİSTEM KİLİDİ KALDIRILDI!"
echo "=========================================="
echo ""
log_success "Tüm koruma mekanizmaları kaldırıldı"
echo ""
log_info "Kaldırılan özellikler:"
echo "  🔓 Uygulama kilitleri"
echo "  🔓 Çöp kutusu koruması"
echo "  🔓 YouTube engeli (IP, DNS, SNI)"
echo "  🔓 VPN protokol engelleri"
echo "  🔓 WiFi yönetimi kısıtlamaları"
echo "  🔓 Bluetooth kısıtlamaları"
echo "  🔓 USB storage kısıtlamaları"
echo ""
log_warning "Sistem şimdi normal durumda"
echo ""

# Yeniden başlatma önerisi
read -p "Değişikliklerin tam olarak uygulanması için sistemi yeniden başlatmak ister misiniz? (evet/hayır): " reboot_now

if [ "$reboot_now" == "evet" ]; then
    log_info "Sistem 5 saniye içinde yeniden başlatılıyor..."
    for i in {5..1}; do
        echo -ne "\r$i saniye...  "
        sleep 1
    done
    echo ""
    reboot
else
    log_info "Sistem yeniden başlatılmadı"
    log_warning "Bazı değişikliklerin etkili olması için manuel yeniden başlatma gerekebilir"
fi

exit 0
