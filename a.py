#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SİSTEM GENELİ UYGULAMA KİLİDİ
Tüm uygulamalar (Çöp Kutusu dahil) açılmadan önce şifre ister
Şifre: maniac
"""

import tkinter as tk
from tkinter import messagebox
import subprocess
import os
import sys
import hashlib
import time
import signal

class PasswordProtection:
    def __init__(self, app_name="Uygulama", app_command=None):
        self.app_name = app_name
        self.app_command = app_command
        self.correct_hash = "8c8837b23ff8aaa8a2dde915473ce0d8"  # MD5 of "maniac"
        
        self.root = tk.Tk()
        self.root.title("🔒 Güvenlik Doğrulama")
        self.root.geometry("450x280")
        self.root.resizable(False, False)
        self.root.configure(bg='#1a1a1a')
        
        # Pencereyi her zaman en üstte tut
        self.root.attributes('-topmost', True)
        
        # Kapatma butonunu devre dışı bırak
        self.root.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        self.center_window()
        self.create_widgets()
        
        # Başarısız deneme sayacı
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
        # Kilit ikonu ve başlık
        header_frame = tk.Frame(self.root, bg='#1a1a1a')
        header_frame.pack(pady=20)
        
        tk.Label(
            header_frame,
            text="🔐",
            font=('Arial', 40),
            bg='#1a1a1a',
            fg='#ff6b6b'
        ).pack()
        
        tk.Label(
            header_frame,
            text="GÜVENLİK DOĞRULAMA",
            font=('Arial', 16, 'bold'),
            bg='#1a1a1a',
            fg='#ffffff'
        ).pack(pady=5)
        
        # Uygulama adı
        tk.Label(
            header_frame,
            text=f'"{self.app_name}" uygulamasını açmak için',
            font=('Arial', 10),
            bg='#1a1a1a',
            fg='#888888'
        ).pack()
        
        # Şifre frame
        password_frame = tk.Frame(self.root, bg='#1a1a1a')
        password_frame.pack(pady=20)
        
        tk.Label(
            password_frame,
            text="Şifre:",
            font=('Arial', 12, 'bold'),
            bg='#1a1a1a',
            fg='#ffffff'
        ).pack()
        
        self.password_entry = tk.Entry(
            password_frame,
            font=('Arial', 14),
            show='●',
            width=25,
            bg='#2d2d2d',
            fg='#ffffff',
            insertbackground='#ffffff',
            relief=tk.FLAT,
            bd=2
        )
        self.password_entry.pack(pady=10, ipady=8)
        self.password_entry.bind('<Return>', lambda e: self.check_password())
        self.password_entry.focus()
        
        # Butonlar
        button_frame = tk.Frame(self.root, bg='#1a1a1a')
        button_frame.pack(pady=15)
        
        self.unlock_btn = tk.Button(
            button_frame,
            text="🔓 Kilidi Aç",
            command=self.check_password,
            font=('Arial', 11, 'bold'),
            bg='#4CAF50',
            fg='white',
            width=15,
            height=2,
            cursor='hand2',
            relief=tk.FLAT,
            activebackground='#45a049'
        )
        self.unlock_btn.pack(side=tk.LEFT, padx=5)
        
        tk.Button(
            button_frame,
            text="❌ İptal",
            command=self.cancel,
            font=('Arial', 11, 'bold'),
            bg='#f44336',
            fg='white',
            width=15,
            height=2,
            cursor='hand2',
            relief=tk.FLAT,
            activebackground='#da190b'
        ).pack(side=tk.LEFT, padx=5)
        
        # Durum mesajı
        self.status_label = tk.Label(
            self.root,
            text="",
            font=('Arial', 9),
            bg='#1a1a1a',
            fg='#ff6b6b'
        )
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
                self.status_label.config(
                    text=f"❌ Yanlış şifre! Kalan deneme: {remaining}",
                    fg='#ff6b6b'
                )
                self.password_entry.delete(0, tk.END)
                self.password_entry.focus()
                
                # Pencereyi titret
                self.shake_window()
                
                if remaining <= 2:
                    messagebox.showwarning(
                        "Uyarı",
                        f"Yanlış şifre!\nKalan deneme hakkı: {remaining}\n\nDikkat: Tüm denemeler tükenirse uygulama kapanacak!"
                    )
            else:
                messagebox.showerror(
                    "Erişim Engellendi",
                    "Çok fazla başarısız deneme!\nGüvenlik nedeniyle erişim engellendi."
                )
                self.cancel()
    
    def shake_window(self):
        """Pencereyi titreterek yanlış şifre efekti ver"""
        x = self.root.winfo_x()
        y = self.root.winfo_y()
        
        for i in range(3):
            self.root.geometry(f'+{x-10}+{y}')
            self.root.update()
            time.sleep(0.05)
            self.root.geometry(f'+{x+10}+{y}')
            self.root.update()
            time.sleep(0.05)
        
        self.root.geometry(f'+{x}+{y}')
    
    def launch_app(self):
        """Şifre doğruysa uygulamayı başlat"""
        if self.app_command:
            try:
                subprocess.Popen(self.app_command, shell=True, start_new_session=True)
            except Exception as e:
                messagebox.showerror("Hata", f"Uygulama başlatılamadı:\n{e}")
        
        self.root.destroy()
    
    def cancel(self):
        """İptal tuşu veya kapama"""
        self.root.destroy()
        sys.exit(0)
    
    def on_closing(self):
        """X tuşuna basıldığında"""
        response = messagebox.askyesno(
            "Çıkış",
            "Uygulamayı açmadan çıkmak istediğinizden emin misiniz?"
        )
        if response:
            self.cancel()
    
    def run(self):
        self.root.mainloop()


def main():
    # Komut satırı argümanlarından uygulama bilgilerini al
    if len(sys.argv) > 1:
        app_name = sys.argv[1]
        app_command = sys.argv[2] if len(sys.argv) > 2 else None
    else:
        # Test modu
        app_name = "Test Uygulaması"
        app_command = None
    
    protector = PasswordProtection(app_name, app_command)
    protector.run()


if __name__ == "__main__":
    main()
