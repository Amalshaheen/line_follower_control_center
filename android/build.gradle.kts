allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        // Force specific versions to resolve conflicts
        resolutionStrategy {
            force("com.google.android.material:material:1.11.0")
            force("androidx.appcompat:appcompat:1.7.0")
        }
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
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
