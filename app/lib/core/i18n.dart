/// Đa ngôn ngữ tối giản: L.t('vi','en','ko') — đổi L.lang là toàn UI rebuild qua AppState.
library;

class L {
  static String lang = 'vi'; // vi | en | ko
  static String t(String vi, String en, String ko) =>
      switch (lang) { 'en' => en, 'ko' => ko, _ => vi };
}
