plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.facilitymanager.english_step"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.facilitymanager.english_step"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 요즘 폰(64비트 ARM)만 지원. 구형 32비트폰·x86 에뮬레이터용 코드를 빼서 APK 용량을 줄인다.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    // 서명 키 두 개.
    // - debug(ci-debug.keystore, 테스트 전용): 직접 설치용 APK. PC·Actions 빌드가 같은 키라
    //   폰에서 삭제 없이 업데이트된다.
    // - upload: Google Play 업로드용(AAB). 키 파일과 비밀번호는 저장소에 넣지 않는다.
    //   android/key.properties(커밋 안 됨) 또는 환경변수 UPLOAD_KEYSTORE_PATH / UPLOAD_KEYSTORE_PASSWORD
    //   (GitHub Actions에서는 Secrets로 넣어준다)에서 읽는다.
    val keyProps = java.util.Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) f.inputStream().use { load(it) }
    }
    val uploadStore = keyProps.getProperty("storeFile") ?: System.getenv("UPLOAD_KEYSTORE_PATH")
    val uploadPass = keyProps.getProperty("storePassword") ?: System.getenv("UPLOAD_KEYSTORE_PASSWORD")

    signingConfigs {
        getByName("debug") {
            storeFile = file("ci-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (uploadStore != null && uploadPass != null) {
            create("upload") {
                storeFile = file(uploadStore)
                storePassword = uploadPass
                keyAlias = keyProps.getProperty("keyAlias") ?: "upload"
                keyPassword = uploadPass
            }
        }
    }

    buildTypes {
        release {
            // Play 업로드용 빌드만 업로드 키로 서명한다:
            //   flutter build appbundle --release --android-project-arg=playUpload=true
            val usePlayKey = project.hasProperty("playUpload")
            if (usePlayKey && signingConfigs.findByName("upload") == null) {
                throw GradleException("업로드 키가 없어요. key.properties나 UPLOAD_KEYSTORE_* 환경변수를 확인하세요.")
            }
            signingConfig = signingConfigs.getByName(if (usePlayKey) "upload" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
