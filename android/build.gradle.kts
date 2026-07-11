allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/*
|--------------------------------------------------------------------------
| Force compileSdk for all Android library plugins
|--------------------------------------------------------------------------
| image_cropper and other Flutter plugins may compile with android-33
| from older Flutter defaults. This forces every Android module/plugin
| to compile with SDK 36.
*/
subprojects {
    afterEvaluate {
        if (
                plugins.hasPlugin("com.android.application") ||
                plugins.hasPlugin("com.android.library")
        ) {
            extensions.configure<com.android.build.gradle.BaseExtension>("android") {
                compileSdkVersion(36)

                defaultConfig {
                    minSdk = 23
                }
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}