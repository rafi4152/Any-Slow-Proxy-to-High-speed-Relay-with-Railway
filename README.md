⚡ IPCook SOCKS5 Proxy Manager

একটি Lightweight, Advanced & Mobile-Friendly SOCKS5 Proxy Manager 🚀
Railway-তে সহজে deploy করে এক জায়গা থেকে IPCook proxy manage, test, switch এবং auto-rotate করা যায়।

---

✨ প্রধান ফিচারসমূহ

🧦 SOCKS5 Proxy Support

মোবাইল বা অ্যাপে সহজে SOCKS5 হিসেবে কানেক্ট করা যাবে।

🟢 Proxy Health Check

প্রতিটি proxy ব্যবহারের আগে পরীক্ষা করা যায়।

Status| অর্থ
🟢 ✓ READY| Proxy কাজ করছে
🟡 ⟳ CHECKING| বর্তমানে পরীক্ষা হচ্ছে
🔴 ✕ FAILED| Proxy কাজ করছে না
⚪ ? UNKNOWN| এখনো পরীক্ষা করা হয়নি
⭐ ACTIVE| বর্তমানে ব্যবহার হচ্ছে

🔄 Auto Rotation

নির্দিষ্ট সময় পরপর স্বয়ংক্রিয়ভাবে একটি proxy থেকে অন্য proxy-তে পরিবর্তন করা যায়।

🎛️ Advanced Dashboard

- ➕ নতুন proxy যোগ
- 🔍 Proxy test
- ⚡ Manual switch
- 🔄 Auto rotation
- ❌ Bad proxy delete
- 🚫 Proxy enable/disable
- 📊 Active connection দেখা
- 🚦 Speed limit সেট করা

📱 Mobile Friendly

সম্পূর্ণ responsive এবং মোবাইল থেকে সহজে ব্যবহারযোগ্য।

🪶 Lightweight

- ❌ কোনো npm package নেই
- ❌ Database নেই
- 📦 মাত্র একটি Dockerfile
- ⚡ কম resource ব্যবহারের জন্য তৈরি
- 🎯 200 MB RAM-এর মধ্যে চালানোর লক্ষ্য

---

🏗️ Connection System

📱 Your Mobile / App
        │
        │ SOCKS5
        ▼
🚂 Railway TCP Proxy
        │
        ▼
⚡ IPCook SOCKS5 Manager
        │
        │ HTTP CONNECT
        ▼
🌍 IPCook Rotating Proxy
        │
        ▼
🌐 Internet

---

📁 GitHub Repository Setup

Repository-তে শুধু একটি ফাইল প্রয়োজন:

Dockerfile

এই project-এ কোনো আলাদা:

❌ package.json
❌ requirements.txt
❌ index.js
❌ server.js

দরকার নেই।

সবকিছু একটি Dockerfile-এর ভিতরেই রয়েছে। 🔥

---

🚀 Railway Deploy

1️⃣ GitHub Repository তৈরি করুন

GitHub-এ একটি নতুন repository তৈরি করুন এবং সেখানে:

Dockerfile

ফাইলটি upload করুন।

2️⃣ Railway-তে Deploy

Railway খুলে:

New Project
        ↓
Deploy from GitHub Repo
        ↓
আপনার Repository Select
        ↓
Deploy

Railway স্বয়ংক্রিয়ভাবে Dockerfile detect করে deploy শুরু করবে। 🚂

---

🔐 Railway Variable

Railway Dashboard → Variables এ যান।

নিচের variable যোগ করুন:

ADMIN_TOKEN

Value হিসেবে নিজের একটি শক্তিশালী password দিন।

উদাহরণ:

ADMIN_TOKEN = MyStrongSecretToken123!

⚠️ এটি অন্য কাউকে দেবেন না।

---

🌐 Dashboard Access

Railway-তে:

Settings
        ↓
Networking
        ↓
Generate Domain

এই Public URL খুললে Dashboard দেখতে পাবেন।

তারপর:

ADMIN_TOKEN

দিয়ে Dashboard unlock করুন। 🔐

---

🧦 Mobile SOCKS5 Setup

Railway-তে TCP Proxy তৈরি করুন।

তারপর আপনার SOCKS5 app-এ:

Proxy Type: SOCKS5

Host: Railway TCP Proxy Host

Port: Railway TCP Proxy Port

Username: খালি

Password: খালি

তারপর Connect করুন। 📱⚡

---

➕ IPCook Proxy Add

Dashboard-এ নিচের format ব্যবহার করুন:

host:port@username:password

উদাহরণ:

geo-sg.ipcook.com:32345@USERNAME:PASSWORD

তারপর:

Add Proxy

চাপুন।

---

🟢 Proxy ব্যবহার করার আগে Check করুন

প্রতিটি proxy-এর পাশে:

✓ Check

button থাকবে।

Proxy ভালো হলে:

🟢 READY

এবং Proxy কাজ না করলে:

🔴 FAILED

দেখাবে।

তারপর:

Use

চাপলে সেই proxy Active হবে। ⭐

---

🔄 Auto Rotation

Dashboard থেকে:

Interval

সেট করুন।

উদাহরণ:

60 seconds
300 seconds
600 seconds

তারপর:

☑ Enable Auto Rotation

এবং:

Save Settings

চাপুন।

⚡ এরপর নির্ধারিত সময় পর proxy স্বয়ংক্রিয়ভাবে পরিবর্তন হবে।

---

🚦 Speed Limit

Dashboard থেকে Download Cap সেট করা যায়।

উদাহরণ:

0 KB/s  = Unlimited
500 KB/s
1024 KB/s
5120 KB/s
10240 KB/s

⚠️ গুরুত্বপূর্ণ:

Speed limit বাড়ালে upstream proxy-এর আসল speed বাড়বে না।

এটি শুধু relay-এর traffic limit নিয়ন্ত্রণ করে।

---

📊 Resource Usage

এই project lightweight রাখার জন্য:

- Node.js built-in modules ব্যবহার করা হয়েছে
- কোনো heavy framework নেই
- কোনো external dependency নেই
- কোনো database নেই
- কোনো npm install প্রয়োজন নেই

🎯 Railway-এর কম resource ব্যবহার করে দ্রুত SOCKS5 relay চালানোর জন্য তৈরি।

---

⚠️ গুরুত্বপূর্ণ বিষয়

🔹 একই proxy provider ব্যবহার করলে proxy-এর আসল speed provider এবং routing-এর উপর নির্ভর করবে।

🔹 Railway server দ্রুত হলেও slow upstream proxy জোর করে দ্রুত করা সম্ভব নয়।

🔹 "READY" status পাওয়ার জন্য proxy test করতে হবে।

🔹 Active proxy পরিবর্তন হলে পুরোনো connection disconnect হতে পারে।

🔹 Auto Rotation চালু থাকলে নতুন proxy ব্যবহার করতে app-কে reconnect করতে হতে পারে।

🔹 Dashboard Public URL এবং SOCKS5 TCP Proxy endpoint এক নয়।

---

🛠️ Quick Troubleshooting

❌ SOCKS5 Connect হচ্ছে না

Check করুন:

✓ Railway TCP Proxy তৈরি হয়েছে?
✓ Host সঠিক?
✓ Port সঠিক?
✓ Proxy Type = SOCKS5?
✓ IPCook proxy Dashboard থেকে READY?

❌ Dashboard খুলছে না

Check করুন:

✓ Railway Public Domain তৈরি হয়েছে?
✓ ADMIN_TOKEN দেওয়া হয়েছে?
✓ Deployment Running আছে?

❌ Proxy FAILED

Dashboard থেকে:

✓ Check

চালিয়ে দেখুন এবং IPCook:

Host
Port
Username
Password

সঠিক আছে কিনা পরীক্ষা করুন।

---

🔒 Security

এই project private ব্যবহারের জন্য তৈরি।

অবশ্যই:

✓ Strong ADMIN_TOKEN ব্যবহার করুন
✓ TCP Proxy publicভাবে শেয়ার করবেন না
✓ Proxy credentials public GitHub repository-তে রাখবেন না
✓ Dashboard URL সুরক্ষিত রাখুন

---

⚡ Quick Start

📁 Upload Dockerfile
        ↓
🐙 Push to GitHub
        ↓
🚂 Deploy to Railway
        ↓
🔐 Add ADMIN_TOKEN
        ↓
🌐 Generate Public Domain
        ↓
🧦 Create Railway TCP Proxy
        ↓
🟢 Add & Check IPCook Proxy
        ↓
📱 Connect with SOCKS5 App
        ↓
🚀 Done!

---

❤️ Made for Lightweight Proxy Management

SOCKS5 • Railway • IPCook • Auto Rotation • Proxy Health Check • Mobile Dashboard

⚡ Fast Setup — Lightweight Design — Advanced Control
