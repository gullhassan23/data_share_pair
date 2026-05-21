allprojects {
    repositories {
        google()
        mavenCentral()
        // GameAnalytics Android SDK (required by gameanalytics_sdk Flutter plugin)
        maven {
            url = uri("https://maven.gameanalytics.com/release")
        }
        // Mintegral / Mbridge SDK (required by gma_mediation_mintegral)
        maven {
            url = uri("https://dl-maven-android.mintegral.com/repository/mbridge_android_sdk_oversea")
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
