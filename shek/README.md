# ماسح الأسعار

تطبيق Flutter لأجهزة Android لمسح باركود المنتج، وإدخال اسمه وسعره يدويًا، ثم طباعة بطاقة سعر على طابعة حرارية Bluetooth تدعم ESC/POS.

## المتطلبات

- Flutter 3.47.6 أو أحدث متوافق مع الحزم المحددة في `pubspec.yaml`.
- هاتف Android بكاميرا، وطابعة حرارية Bluetooth مقترنة مسبقًا من إعدادات الهاتف.
- ورق حراري بعرض 58 مم أو 80 مم.

## التشغيل والبناء

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

ملف APK الناتج: `build/app/outputs/flutter-apk/app-release.apk`.

## الرفع إلى GitHub

أنشئ مستودعًا فارغًا على GitHub، ثم اربطه وارفع ملفات المصدر والإعدادات فقط. ملفات البناء والكاش مثل `build/` و`.dart_tool/` وملفات إعداد Android المحلية مستثناة عبر `.gitignore`، بينما يبقى `pubspec.lock` ضمن المستودع لتثبيت إصدارات الاعتماديات.

```sh
git add .
git commit -m "Initial project setup"
git remote add origin https://github.com/USERNAME/REPOSITORY.git
git push -u origin main
```

لا ترفع مفاتيح التوقيع أو `android/key.properties` إلى المستودع.

## توقيع إصدار Android

أنشئ مفتاح رفع محليًا مرة واحدة من PowerShell:

```powershell
.\android\setup_signing.ps1
```

ينشئ الأمر `android/app/upload-keystore.jks` وملف الإعدادات السري `android/key.properties` بكلمة مرور عشوائية. لا ترفع هذين الملفين إلى Git أو تشاركهما. احتفظ بنسخة احتياطية آمنة من كليهما؛ فقدان المفتاح يمنع تحديث التطبيق المنشور بهذا المعرّف. بعد تثبيت Android SDK، أنشئ APK موقعًا باستخدام `flutter build apk --release`.

معرّف Android الحالي هو `com.shek.pricelabelscanner`. اختر المعرّف النهائي بعناية قبل أول نشر؛ لا تغيّره بعد نشر التطبيق.

## الطباعة

بعد إقران الطابعة من إعدادات Bluetooth، حدّدها داخل التطبيق واتصل بها. البطاقة تطبع اسم المنتج والسعر كصورة حتى تظهر النصوص العربية بشكل صحيح، ثم تطبع الباركود بصيغة Code 128. اختر عرض الورق المطابق للطابعة قبل الطباعة.

## Bitrise

ملف `bitrise.yml` يثبت Flutter 3.47.6، ويشغّل التحليل والاختبارات، ويبني APK إصدارًا ويرفعه كملف artifact في Bitrise. اربط المستودع بـ Bitrise واختر workflow باسم `primary`.

## ملاحظات

- اسم المنتج والسعر يُدخلان يدويًا بعد كل عملية مسح؛ لا يتطلب التطبيق نظام مخزون أو اتصالًا بخدمة خارجية.
- العملة غير مفروضة في التطبيق؛ السعر يطبع كما أدخله المستخدم.
- الطابعات الظاهرة هي أجهزة Bluetooth المقترنة بالنظام. يجب دعم الطابعة لأوامر ESC/POS.
