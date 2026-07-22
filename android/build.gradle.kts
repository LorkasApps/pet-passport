allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force all Flutter plugins to compile against a modern Android SDK so
    // transitive AAR requirements (e.g. flutter_plugin_android_lifecycle
    // needs 36+) resolve. Without this, plugins built against 34 can hold
    // the app back.
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            (extensions.getByName("android") as com.android.build.gradle.BaseExtension).apply {
                compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
