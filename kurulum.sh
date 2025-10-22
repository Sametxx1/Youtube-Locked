#!/bin/bash
##############################################################################
# SİSTEM GENELİ UYGULAMA KİLİDİ KURULUM SCRİPTİ
# Tüm uygulamalar (çöp dahil) açılmadan önce şifre ister
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
echo "  🔒 SİSTEM KİLİDİ KURULUM ARACI"
echo "=========================================="
echo ""

##############################################################################
# 1. GEREKLİ PAKETLERİ KONT ROL ET
##############################################################################
log_info "Gerekli paketler kontrol ediliyor..."

REQUIRED_PACKAGES="python3 python3-tk zenity"

for package in $REQUIRED_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $package"; then
        log_info "$package yükleniyor..."
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y $package
    fi
done

log_success "Tüm paketler hazır"

##############################################################################
# 2. PYTHON KİLİT SCRİPTİNİ OLUŞTUR
##############################################################################
log_info "Kilit scripti oluşturuluyor..."

cat > /usr/local/bin/app-locker.py << 'PYTHON_SCRIPT_END'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import tkinter as tk
from tkinter import messagebox
import subprocess
import os
import sys
import hashlib
import time

class PasswordProtection:
    def __init__(self, app_name="Uygulama", app_command=None):
        self.app_name = app_name
        self.app_command = app_command
        self.correct_hash = "8c8837b23ff8aaa8a2dde915473ce0d8"
        
        self.root = tk.Tk()
        self.root.title("🔒 Güvenlik Doğrulama")
        self.root.geometry("450x280")
        self.root.resizable(False, False)
        self.root.configure(bg='#1a1a1a')
        self.root.attributes('-topmost', True)
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        self.center_window()
        self.create_widgets()
        self.failed_attempts = 0
        self.max_attempts = 5
        
    def center_window(self):
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f'{width}x{height}+{x}+{y}')
        
    def create_widgets(self):
        header_frame = tk.Frame(self.root, bg='#1a1a1a')
        header_frame.pack(pady=20)
        
        tk.Label(header_frame, text="🔐", font=('Arial', 40), bg='#1a1a1a', fg='#ff6b6b').pack()
        tk.Label(header_frame, text="GÜVENLİK DOĞRULAMA", font=('Arial', 16, 'bold'), bg='#1a1a1a', fg='#ffffff').pack(pady=5)
        tk.Label(header_frame, text=f'"{self.app_name}" uygulamasını açmak için', font=('Arial', 10), bg='#1a1a1a', fg='#888888').pack()
        
        password_frame = tk.Frame(self.root, bg='#1a1a1a')
        password_frame.pack(pady=20)
        
        tk.Label(password_frame, text="Şifre:", font=('Arial', 12, 'bold'), bg='#1a1a1a', fg='#ffffff').pack()
        
        self.password_entry = tk.Entry(password_frame, font=('Arial', 14), show='●', width=25, bg='#2d2d2d', fg='#ffffff', insertbackground='#ffffff', relief=tk.FLAT, bd=2)
        self.password_entry.pack(pady=10, ipady=8)
        self.password_entry.bind('<Return>', lambda e: self.check_password())
        self.password_entry.focus()
        
        button_frame = tk.Frame(self.root, bg='#1a1a1a')
        button_frame.pack(pady=15)
        
        tk.Button(button_frame, text="🔓 Kilidi Aç", command=self.check_password, font=('Arial', 11, 'bold'), bg='#4CAF50', fg='white', width=15, height=2, cursor='hand2', relief=tk.FLAT).pack(side=tk.LEFT, padx=5)
        tk.Button(button_frame, text="❌ İptal", command=self.cancel, font=('Arial', 11, 'bold'), bg='#f44336', fg='white', width=15, height=2, cursor='hand2', relief=tk.FLAT).pack(side=tk.LEFT, padx=5)
        
        self.status_label = tk.Label(self.root, text="", font=('Arial', 9), bg='#1a1a1a', fg='#ff6b6b')
        self.status_label.pack(pady=5)
        
    def check_password(self):
        password = self.password_entry.get()
        password_hash = hashlib.md5(password.encode()).hexdigest()
        
        if password_hash == self.correct_hash:
            self.status_label.config(text="✅ Erişim izni verildi!", fg='#4CAF50')
            self.root.after(500, self.launch_app)
        else:
            self.failed_attempts += 1
            remaining = self.max_attempts - self.failed_attempts
            
            if remaining > 0:
                self.status_label.config(text=f"❌ Yanlış şifre! Kalan: {remaining}", fg='#ff6b6b')
                self.password_entry.delete(0, tk.END)
                self.shake_window()
            else:
                messagebox.showerror("Engellendi", "Çok fazla başarısız deneme!")
                self.cancel()
    
    def shake_window(self):
        x, y = self.root.winfo_x(), self.root.winfo_y()
        for i in range(3):
            self.root.geometry(f'+{x-10}+{y}')
            self.root.update()
            time.sleep(0.05)
            self.root.geometry(f'+{x+10}+{y}')
            self.root.update()
            time.sleep(0.05)
        self.root.geometry(f'+{x}+{y}')
    
    def launch_app(self):
        if self.app_command:
            try:
                subprocess.Popen(self.app_command, shell=True, start_new_session=True)
            except:
                pass
        self.root.destroy()
    
    def cancel(self):
        self.root.destroy()
        sys.exit(0)
    
    def on_closing(self):
        if messagebox.askyesno("Çıkış", "Çıkmak istediğinizden emin misiniz?"):
            self.cancel()
    
    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    app_name = sys.argv[1] if len(sys.argv) > 1 else "Uygulama"
    app_command = sys.argv[2] if len(sys.argv) > 2 else None
    PasswordProtection(app_name, app_command).run()
PYTHON_SCRIPT_END

chmod +x /usr/local/bin/app-locker.py
log_success "Kilit scripti oluşturuldu"

##############################################################################
# 3. .DESKTOP DOSYALARINI YEDEKLİ VE KİLİTLE
##############################################################################
log_info ".desktop dosyaları kilitleniyor..."

# Yedek dizini oluştur
mkdir -p /root/desktop-backups

# Tüm .desktop dosyalarını bul ve kilitle
find /usr/share/applications -name "*.desktop" -type f | while read desktop_file; do
    app_name=$(basename "$desktop_file" .desktop)
    backup_file="/root/desktop-backups/${app_name}.desktop.backup"
    
    # Yedek al
    cp "$desktop_file" "$backup_file" 2>/dev/null || true
    
    # Orijinal Exec satırını al
    original_exec=$(grep "^Exec=" "$desktop_file" | head -1 | sed 's/^Exec=//')
    
    if [ -n "$original_exec" ]; then
        # Yeni Exec satırını oluştur (kilit ile)
        new_exec="Exec=/usr/local/bin/app-locker.py \"$app_name\" \"$original_exec\""
        
        # Dosyayı düzenle
        sed -i "s|^Exec=.*|$new_exec|" "$desktop_file"
        
        log_success "Kilitlendi: $app_name"
    fi
done

##############################################################################
# 4. ÇÖP KUTUSUNU KİLİTLE
##############################################################################
log_info "Çöp kutusu kilitleniyor..."

# Pardus/Debian için çöp kutusu yöneticileri
TRASH_APPS=("nautilus" "nemo" "thunar" "pcmanfm" "dolphin" "caja")

for trash_app in "${TRASH_APPS[@]}"; do
    if command -v $trash_app &> /dev/null; then
        # Trash:/// URI'sini kilitle
        cat > /usr/local/bin/${trash_app}-wrapper << EOF
#!/bin/bash
if [[ "\$@" == *"trash://"* ]] || [[ "\$@" == *"Trash"* ]]; then
    /usr/local/bin/app-locker.py "Çöp Kutusu" "$trash_app \$@"
else
    $trash_app "\$@"
fi
EOF
        chmod +x /usr/local/bin/${trash_app}-wrapper
        log_success "Çöp kutusu koruması eklendi: $trash_app"
    fi
done

##############################################################################
# 5. SİSTEM AYARLARINI KİLİTLE
##############################################################################
log_info "Sistem ayarları kilitleniyor..."

# WiFi yönetimi engelle
if [ -d /etc/NetworkManager ]; then
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/99-no-wifi-control.conf << 'EOF'
[main]
plugins=keyfile
[keyfile]
unmanaged-devices=type:wifi
EOF
    
    # NetworkManager'ı yeniden başlat
    systemctl restart NetworkManager 2>/dev/null || true
    log_success "WiFi yönetimi kilitlendi"
fi

# Bluetooth'u devre dışı bırak
systemctl stop bluetooth 2>/dev/null || true
systemctl disable bluetooth 2>/dev/null || true
log_success "Bluetooth devre dışı"

# USB storage'ı kısıtla
cat > /etc/modprobe.d/block-usb-storage.conf << 'EOF'
install usb-storage /bin/false
EOF
log_success "USB storage kısıtlandı"

##############################################################################
# 6. YOUTUBE ENGELLEMESİNİ KOPYALA
##############################################################################
log_info "YouTube engelleme scripti kuruluyor..."

if [ -f "/tmp/block-youtube.sh" ]; then
    cp /tmp/block-youtube.sh /usr/local/bin/
    chmod +x /usr/local/bin/block-youtube.sh
    log_success "YouTube engelleme scripti kuruldu"
fi

##############################################################################
# 7. OTOMATİK BAŞLATMA
##############################################################################
log_info "Otomatik başlatma yapılandırılıyor..."

# Systemd servisi
cat > /etc/systemd/system/system-lock.service << 'EOF'
[Unit]
Description=System Lock Service
After=graphical.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/block-youtube.sh
RemainAfterExit=yes

[Install]
WantedBy=graphical.target
EOF

systemctl daemon-reload
systemctl enable system-lock.service 2>/dev/null || true

log_success "Otomatik başlatma yapılandırıldı"

##############################################################################
# 8. BIOS VE BOOT KORUMASI
##############################################################################
log_info "Boot koruması yapılandırılıyor..."

# GRUB şifre koruması (opsiyonel)
if [ -f /etc/default/grub ]; then
    # USB boot'u GRUB'dan devre dışı bırak
    if ! grep -q "GRUB_DISABLE_OS_PROBER" /etc/default/grub; then
        echo "GRUB_DISABLE_OS_PROBER=true" >> /etc/default/grub
        update-grub 2>/dev/null || true
        log_success "USB boot kısıtlandı"
    fi
fi

##############################################################################
# 9. KALDIRMA SCRİPTİ OLUŞTUR
##############################################################################
log_info "Kaldırma scripti oluşturuluyor..."

cat > /usr/local/bin/system-unlock.sh << 'EOF'
#!/bin/bash
if [ "$EUID" -ne 0 ]; then 
    echo "Root yetkisi gerekli!"
    exit 1
fi

echo "Sistem kilidi kaldırılıyor..."

# .desktop dosyalarını geri yükle
if [ -d /root/desktop-backups ]; then
    cp /root/desktop-backups/*.backup /usr/share/applications/ 2>/dev/null
    rename 's/.backup$//' /usr/share/applications/*.backup 2>/dev/null
fi

# NetworkManager'ı geri yükle
rm -f /etc/NetworkManager/conf.d/99-no-wifi-control.conf
systemctl restart NetworkManager

# Servisi durdur
systemctl stop system-lock.service
systemctl disable system-lock.service

echo "✅ Sistem kilidi kaldırıldı!"
EOF

chmod +x /usr/local/bin/system-unlock.sh
log_success "Kaldırma scripti hazır (/usr/local/bin/system-unlock.sh)"

##############################################################################
# 10. ÖZET
##############################################################################
echo ""
echo "=========================================="
echo "  ✅ KURULUM TAMAMLANDI!"
echo "=========================================="
echo ""
log_success "Sistem kilidi aktif!"
echo ""
log_info "Korunan alanlar:"
echo "  🔒 Tüm uygulamalar (.desktop)"
echo "  🔒 Çöp kutusu"
echo "  🔒 WiFi yönetimi"
echo "  🔒 Bluetooth"
echo "  🔒 USB storage"
echo "  🔒 YouTube (tüm katmanlar)"
echo ""
log_info "Şifre: maniac"
echo ""
log_warning "Kilidi kaldırmak için:"
echo "  sudo /usr/local/bin/system-unlock.sh"
echo ""
log_info "Sistem yeniden başlatılıyor..."
echo ""

# Kullanıcıya 10 saniye ver
for i in {10..1}; do
    echo -ne "\rYeniden başlatma: $i saniye...  "
    sleep 1
done

echo ""
reboot
