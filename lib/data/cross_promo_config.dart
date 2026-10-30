/// 相互紹介（ukalab_core の `UkalabCrossPromoSection`）に渡す、このアプリの本番 applicationId。
///
/// `android/app/build.gradle.kts` の `applicationId` と一致させる。
/// ukalab_core の `kUkalabAppIds` にある値でなければ、debug ビルドで assert に気づける。
const kInfoSecurityApplicationId = 'com.yourwish.ukalab.infosecmanage';
