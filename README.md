# আমার সকাল ২৪ — অ্যান্ড্রয়েড অ্যাপ

ওয়েবসাইটের `as-app/v1` API থেকে খবর, ক্যাটাগরি, ভিডিও ও সার্চ দেখায়।
সেটিংস (রঙ, নাম, API ঠিকানা): `lib/config.dart`

## পদ্ধতি ক — GitHub দিয়ে APK (কম্পিউটারে কিছু ইনস্টল লাগে না)
1. github.com এ একটি নতুন (Private) রিপোজিটরি বানান।
2. এই ফোল্ডারের সব ফাইল (`.github` ফোল্ডারসহ) আপলোড করুন।
3. রিপোজিটরির **Actions** ট্যাবে গিয়ে **Build APK** → **Run workflow** চাপুন।
4. প্রায় ৮–১২ মিনিট পরে কাজ শেষ হলে ওই রানের নিচে **Artifacts** থেকে `amarsokal24-apk` ডাউনলোড করুন। zip খুললে `app-release.apk` পাবেন।

## পদ্ধতি খ — নিজের কম্পিউটারে
1. Flutter SDK ও Android Studio ইনস্টল করুন।
2. এই ফোল্ডারে টার্মিনাল খুলে:
   flutter create --org com.amarsokal24 --project-name amarsokal24_app --platforms android /tmp/scaffold
   (Windows এ /tmp এর জায়গায় যেকোনো খালি ফোল্ডার দিন) তারপর তার `android` ফোল্ডার এই ফোল্ডারে কপি করুন।
3. `android/app/src/main/AndroidManifest.xml` এ `<manifest ...>` ট্যাগের ঠিক নিচে যোগ করুন:
   <uses-permission android:name="android.permission.INTERNET"/>
4. flutter pub get && flutter build apk --release
5. APK: build/app/outputs/flutter-apk/app-release.apk

## প্লে স্টোরের আগে লাগবে
- নিজের signing key (keystore) বানিয়ে release build সেটা দিয়ে সাইন করা
- AAB ফাইল (`flutter build appbundle`)
- অ্যাপ আইকন (লোগো) ও স্ক্রিনশট, প্রাইভেসি পলিসি পেজের লিংক
