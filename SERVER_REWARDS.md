# সার্ভারে যা যোগ করতে হবে (asr/v1 রিওয়ার্ড প্লাগইন)

অ্যাপ (v1.15.0) ভিডিও/রিলসের কয়েনের জন্য নিচের ২টি এন্ডপয়েন্ট ডাকে। সার্ভারে না থাকলে অ্যাপ কয়েন-পিল নিজে লুকিয়ে ফেলে (কোনো এরর দেখায় না)।
আপনার প্লাগইনের ledger/কয়েন-যোগের ফাংশনের নাম আমি জানি না, তাই নিচেরটা কাঠামো — `asr_add_coins()` আপনার প্লাগইনের আসল ফাংশন দিয়ে বদলান।

## config (GET /config ও /me → config)
নতুন key: `video_coin`=7, `video_daily_max`=10, `reel_coin`=4, `reel_daily_max`=25, `rep_news_coin`=1

## POST /media/start   (form: kind=video|reel, media_id, duration)
- লগইন যাচাই (X-ASR-Token)। user+kind+media_id এর জন্য `started_at` সময় সেভ করুন।

## POST /media/claim   (form: kind, media_id, watched, duration)
```php
// কাঠামো
$u = asr_current_user();                       // টোকেন থেকে
$coin = $kind === 'video' ? get_option('asr_video_coin',7) : get_option('asr_reel_coin',4);
$max  = $kind === 'video' ? get_option('asr_video_daily_max',10) : get_option('asr_reel_daily_max',25);
// ১) আগে নেওয়া? (user+kind+media_id ইউনিক) -> ['state'=>'claimed']
// ২) আজকের এই kind এ নেওয়া সংখ্যা >= $max -> ['state'=>'limit']
// ৩) now - started_at  < 0.8 * duration  (বা watched < 0.85*duration) -> 400/['state'=>'early']
// ৪) asr_add_coins($u, $coin, "$kind:$media_id"); -> ['state'=>'ok','earned'=>$coin]
```
duration সর্বোচ্চ ২ ঘণ্টা ধরুন; ৩ সেকেন্ডের কম ভিডিওতে কয়েন নয়।

## প্রতিনিধির নিউজ পাবলিশ হলে ১ কয়েন
প্রতিনিধির নিউজ WordPress এ পাবলিশ হওয়ার মুহূর্তে (একবারই):
```php
add_action('transition_post_status', function($new,$old,$post){
  if ($new !== 'publish' || $old === 'publish') return;
  if (get_post_meta($post->ID,'_asr_rep_paid',true)) return;
  $rep_uid = /* এই পোস্টের প্রতিনিধি -> তার রিওয়ার্ড অ্যাকাউন্ট (T2 rep_id থেকে) */;
  if (!$rep_uid) return;
  asr_add_coins($rep_uid, (int)get_option('asr_rep_news_coin',1), 'rep_news:'.$post->ID);
  update_post_meta($post->ID,'_asr_rep_paid',1);
},10,3);
```
t2 থেকে নিউজ পাঠানোর সময় প্রতিনিধির আইডি পোস্ট-মেটায় রাখলে এখানে সেটা দিয়ে অ্যাকাউন্ট খুঁজুন।

---
## v1.15.1 — অ্যাপ সার্ভারের কাছ থেকে যা আশা করে (কয়েন না এলে এটা মিলিয়ে দেখুন)

- `/media/start` : সফল হলে যেকোনো 2xx। **404/403** হলে অ্যাপ কয়েন-পিল লুকিয়ে ফেলে। অন্য এরর হলে অ্যাপ ৪ সেকেন্ড পরপর ৬ বার চেষ্টা করে; তাতেও না হলে লাল পিল দেখায়। সার্ভারে `started_at` **প্রথম** কলেই বসান; পরের কলে বদলাবেন না (নইলে "early" আসবে)।
- `/media/claim` উত্তর (HTTP 200) এর `state`:
  - `ok` + `earned` → কয়েন যোগ হয়েছে (সার্ভারে সত্যিই লেজারে যোগ করে তারপর এটা ফেরত দিন)
  - `claimed` → আগেই নেওয়া; `limit` → আজকের সীমা শেষ
  - `early` (+ ঐচ্ছিক `wait` সেকেন্ড) → অ্যাপ নিজে থেমে আবার চেষ্টা করে (সর্বোচ্চ ৪ বার)
  - অন্য কিছু / non-2xx → লাল পিলে সার্ভারের `message` দেখায়; পিলে ট্যাপ করলে আবার চেষ্টা। **তাই `message` বাংলায় পরিষ্কার লিখুন।**
- ৪০০/৪২৯/৫xx/নেটওয়ার্ক এরর → অ্যাপ নিজে ৩–৯ সেকেন্ড পরপর ৩ বার আবার চেষ্টা করে।
- `/me` এর `coins` সংখ্যাটি কয়েন যোগের সাথে সাথে আপডেট হতে হবে (অ্যাপ `ok` পাওয়ার পর `/me` আবার আনে)।
