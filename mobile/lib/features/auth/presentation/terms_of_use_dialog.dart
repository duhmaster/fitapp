import 'package:flutter/material.dart';

/// Стандартный текст «Условия использования» для фитнес-приложения (RU).
const String _termsTextRu = '''
УСЛОВИЯ ИСПОЛЬЗОВАНИЯ СЕРВИСА GymMore

1. Общие положения

1.1. Настоящие Условия использования (далее — Условия) регулируют отношения между пользователем (далее — Пользователь) и сервисом GymMore (далее — Сервис) при использовании мобильного приложения и веб-версии для учёта тренировок, прогресса и связанных функций.

1.2. Регистрация и использование Сервиса означают полное и безоговорочное принятие Пользователем настоящих Условий.

2. Регистрация и учётная запись

2.1. Для использования всех функций Сервиса необходимо пройти регистрацию. Пользователь обязуется указывать достоверные данные.

2.2. Пользователь несёт ответственность за сохранность пароля и учётной записи. Рекомендуется не передавать логин и пароль третьим лицам.

3. Использование Сервиса

3.1. Сервис предназначен для персонального учёта тренировок, упражнений, веса тела и других метрик, связанных с фитнесом и здоровьем.

3.2. Пользователь вносит данные самостоятельно. Сервис не предоставляет медицинских или профессиональных рекомендаций. Перед началом тренировок и изменением образа жизни рекомендуется проконсультироваться с врачом.

3.3. Запрещается использовать Сервис в целях, противоречащих законодательству, а также размещать оскорбительный, незаконный или спам-контент.

4. Персональные данные

4.1. Обработка персональных данных осуществляется в соответствии с действующим законодательством и политикой конфиденциальности Сервиса.

4.2. Сервис собирает и хранит только те данные, которые необходимы для работы: email, имя, параметры тела, записи о тренировках.

5. Ограничение ответственности

5.1. Сервис предоставляется «как есть». Разработчики не несут ответственности за возможный вред здоровью в результате использования рекомендаций, данных или приложений, связанных с тренировками.

5.2. Пользователь самостоятельно оценивает состояние здоровья и риски перед выполнением упражнений.

6. Изменение Условий

6.1. Условия могут быть изменены. Актуальная версия публикуется в приложении. Продолжение использования после изменений означает согласие с новой редакцией.

7. Контакты

По вопросам, связанным с Сервисом, обращайтесь через раздел «Помощь» в приложении или на сайт gymmore.ru.
''';

const String _termsTextEn = '''
TERMS OF USE FOR GymMore SERVICE

1. General provisions

1.1. These Terms of Use (hereinafter — the Terms) govern the relationship between the user (hereinafter — the User) and the GymMore service (hereinafter — the Service) when using the mobile app and web version for workout tracking, progress tracking, and related functions.

1.2. Registration and use of the Service constitute full and unconditional acceptance of these Terms by the User.

2. Registration and account

2.1. To use all features of the Service, registration is required. The User agrees to provide accurate information.

2.2. The User is responsible for the security of the password and account. Do not share your credentials with third parties.

3. Use of the Service

3.1. The Service is intended for personal tracking of workouts, exercises, body weight, and other fitness-related metrics.

3.2. The User enters data independently. The Service does not provide medical or professional advice. Consult a doctor before starting exercise programs or making lifestyle changes.

3.3. Use of the Service for illegal purposes or to post offensive, illegal, or spam content is prohibited.

4. Personal data

4.1. Processing of personal data is carried out in accordance with applicable law and the Service's privacy policy.

5. Limitation of liability

5.1. The Service is provided "as is". The developers are not liable for any harm resulting from the use of data, recommendations, or features related to workouts.

6. Changes to the Terms

6.1. The Terms may be amended. The current version is published in the app. Continued use after changes constitutes acceptance of the new version.
''';

void showTermsOfUseDialog(BuildContext context, {String localeCode = 'ru'}) {
  final text = localeCode.startsWith('ru') ? _termsTextRu : _termsTextEn;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(localeCode.startsWith('ru') ? 'Условия использования' : 'Terms of Use'),
      content: SingleChildScrollView(
        child: SelectableText(
          text,
          style: Theme.of(ctx).textTheme.bodySmall,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(localeCode.startsWith('ru') ? 'Закрыть' : 'Close'),
        ),
      ],
    ),
  );
}
