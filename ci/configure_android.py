"""Configures the Android project that `flutter create` generates in CI.

Run from the repo root after `flutter create`. It:
  * sets minSdk 23 and compileSdk 36
  * applies android/namespace-fix.gradle (old plugins on new Gradle)
  * adds a release signing config that reads android/key.properties,
    falling back to the debug key only when that file is missing
Works with both the Kotlin (build.gradle.kts) and Groovy templates and
prints the result so the build log shows exactly what was used.
"""
import pathlib
import re
import sys

android = pathlib.Path("android")
kts = android / "app" / "build.gradle.kts"
groovy = android / "app" / "build.gradle"


def patch_kts(path: pathlib.Path) -> None:
    s = path.read_text()
    s = s.replace("flutter.minSdkVersion", "23")
    s = s.replace("flutter.compileSdkVersion", "36")
    signing = '''
    // Release signing: android/key.properties is written by CI from the
    // ANDROID_KEYSTORE_* repository secrets (see PUBLISHING.md).
    val keyProps = java.util.Properties()
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        keyPropsFile.inputStream().use { keyProps.load(it) }
    }
    signingConfigs {
        create("release") {
            if (keyPropsFile.exists()) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {'''
    s, n = re.subn(r"\n    buildTypes \{", signing, s, count=1)
    if n != 1:
        sys.exit("configure_android: buildTypes block not found in build.gradle.kts")
    s, n = re.subn(
        r'signingConfig = signingConfigs\.getByName\("debug"\)',
        'signingConfig = if (keyPropsFile.exists()) '
        'signingConfigs.getByName("release") else signingConfigs.getByName("debug")',
        s,
    )
    if n == 0:
        sys.exit("configure_android: debug signingConfig line not found")
    path.write_text(s)


def patch_groovy(path: pathlib.Path) -> None:
    s = path.read_text()
    s = s.replace("flutter.minSdkVersion", "23")
    s = s.replace("flutter.compileSdkVersion", "36")
    signing = '''
    def keyProps = new Properties()
    def keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        keyPropsFile.withInputStream { keyProps.load(it) }
    }
    signingConfigs {
        release {
            if (keyPropsFile.exists()) {
                storeFile file(keyProps["storeFile"])
                storePassword keyProps["storePassword"]
                keyAlias keyProps["keyAlias"]
                keyPassword keyProps["keyPassword"]
            }
        }
    }

    buildTypes {'''
    s, n = re.subn(r"\n    buildTypes \{", signing, s, count=1)
    if n != 1:
        sys.exit("configure_android: buildTypes block not found in build.gradle")
    s = re.sub(
        r"signingConfig = signingConfigs\.debug|signingConfig signingConfigs\.debug",
        "signingConfig = keyPropsFile.exists() ? signingConfigs.release : signingConfigs.debug",
        s,
    )
    path.write_text(s)


def apply_root_fix() -> None:
    root_kts = android / "build.gradle.kts"
    root_groovy = android / "build.gradle"
    if root_kts.exists():
        s = root_kts.read_text()
        if "namespace-fix.gradle" not in s:
            root_kts.write_text('apply(from = "namespace-fix.gradle")\n' + s)
    else:
        s = root_groovy.read_text()
        if "namespace-fix.gradle" not in s:
            root_groovy.write_text('apply from: "namespace-fix.gradle"\n' + s)
    props = android / "gradle.properties"
    p = props.read_text()
    if "kotlin.jvm.target.validation.mode" not in p:
        props.write_text(p + "\nkotlin.jvm.target.validation.mode=IGNORE\n")


if kts.exists():
    patch_kts(kts)
    print(kts.read_text())
else:
    patch_groovy(groovy)
    print(groovy.read_text())
apply_root_fix()
print("configure_android: done")
